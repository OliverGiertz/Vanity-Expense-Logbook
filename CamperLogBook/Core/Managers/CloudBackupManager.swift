import Foundation
import CloudKit
import CoreData
import UIKit
import UserNotifications

/// Verwalter für iCloud-Backups der App.
/// Sichert CoreData-Store, Belege und Versionsinformationen als ZIP‑Archiv in iCloud.
@MainActor
class CloudBackupManager: ObservableObject {
    static let shared = CloudBackupManager()

    // CloudKit – Standardcontainer und private Datenbank
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "AppBackup"
    private let backupRecordID = CKRecord.ID(recordName: "currentBackup")

    // Backup Status
    @Published var isBackupInProgress = false
    @Published var isRestoreInProgress = false
    @Published var backupProgress: Double = 0.0
    @Published var restoreProgress: Double = 0.0
    @Published var lastBackupDate: Date?
    @Published var lastBackupStatus: BackupStatus = .none
    @Published var lastErrorMessage: String?

    // Verwenden die bestehenden Export/Import-Coordinatoren
    private var coreDataCoordinator: CoreDataBackupCoordinator?
    private var receiptCoordinator: ReceiptBackupCoordinator?

    // Backup Status Enum
    enum BackupStatus {
        case none, notAvailable, available, inProgress, error
    }

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        Task { await checkiCloudAccountStatus() }
    }

    /// Verbindet die Backup-Komponenten mit dem CoreData-Kontext
    func connect(to context: NSManagedObjectContext) {
        self.coreDataCoordinator = CoreDataBackupCoordinator(context: context)
        self.receiptCoordinator = ReceiptBackupCoordinator(context: context)
    }

    /// Prüft den iCloud-Accountstatus und lädt vorhandenes Backup, falls vorhanden
    private func checkiCloudAccountStatus() async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<CKAccountStatus, Never>) in
            container.accountStatus { status, _ in
                continuation.resume(returning: status)
            }
        }

        if status == .available {
            await loadAvailableBackup()
        } else {
            lastBackupStatus = .notAvailable
            switch status {
            case .noAccount:
                lastErrorMessage = "Kein iCloud-Account angemeldet. Bitte in den Einstellungen bei iCloud anmelden."
            case .restricted:
                lastErrorMessage = "iCloud ist eingeschränkt. Bitte überprüfe die iCloud-Einstellungen."
            case .couldNotDetermine:
                lastErrorMessage = "Der iCloud-Status konnte nicht ermittelt werden."
            default:
                lastErrorMessage = "iCloud ist nicht verfügbar."
            }
        }
    }

    /// Erstellt ein Backup der App-Daten und lädt es in iCloud hoch.
    func createBackup() async throws {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            throw BackupError.notInitialized
        }

        isBackupInProgress = true
        backupProgress = 0.0
        lastErrorMessage = nil

        defer { isBackupInProgress = false }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Schritt 1: CoreData exportieren
        let coreDataURL = tempDir.appendingPathComponent("coredata_backup.sqlite")
        try await coreDataCoordinator.exportStore(to: coreDataURL)
        backupProgress = 0.3

        // Schritt 2: Belege exportieren
        let receiptsURL = tempDir.appendingPathComponent("receipts")
        try? FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
        let receiptCount = try await receiptCoordinator.exportReceipts(to: receiptsURL)
        backupProgress = 0.6

        // Schritt 3: Versionsinformationen
        let versionInfo: [String: Any] = [
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "backupDate": Date(),
            "receiptCount": receiptCount
        ]
        let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
        try versionData.write(to: tempDir.appendingPathComponent("version.plist"))

        // Schritt 4: ZIP erstellen
        let zipURL = tempDir.deletingLastPathComponent().appendingPathComponent("backup.zip")
        try FileManager.default.zipItem(at: tempDir, to: zipURL)
        backupProgress = 0.8

        // Schritt 5: In iCloud hochladen
        try await uploadBackup(zipURL: zipURL)
        try? FileManager.default.removeItem(at: zipURL)

        backupProgress = 1.0
        lastBackupDate = Date()
        lastBackupStatus = .available
    }

    /// Lädt das ZIP-Archiv als CKAsset in iCloud hoch.
    private func uploadBackup(zipURL: URL) async throws {
        let record = CKRecord(recordType: recordType, recordID: backupRecordID)
        record["backupDate"] = Date() as CKRecordValue
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String as CKRecordValue?
        record["backupAsset"] = CKAsset(fileURL: zipURL)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            modifyOp.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            modifyOp.qualityOfService = .userInitiated
            privateDatabase.add(modifyOp)
        }
    }

    /// Stellt ein Backup aus iCloud wieder her.
    func restoreBackup() async throws {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            throw BackupError.notInitialized
        }

        isRestoreInProgress = true
        restoreProgress = 0.0
        lastErrorMessage = nil

        defer { isRestoreInProgress = false }

        let record = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
            privateDatabase.fetch(withRecordID: backupRecordID) { record, error in
                if let record = record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: error ?? BackupError.backupNotFound)
                }
            }
        }

        guard let asset = record["backupAsset"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw BackupError.noAsset
        }

        restoreProgress = 0.3

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: fileURL, to: tempDir)

        restoreProgress = 0.6

        let coreDataURL = tempDir.appendingPathComponent("coredata_backup.sqlite")
        guard FileManager.default.fileExists(atPath: coreDataURL.path) else {
            throw BackupError.missingCoreDataBackup
        }

        try coreDataCoordinator.importStore(from: coreDataURL)
        restoreProgress = 0.8

        let receiptsURL = tempDir.appendingPathComponent("receipts")
        try await receiptCoordinator.importReceipts(from: receiptsURL)

        restoreProgress = 1.0
    }

    /// Lädt das vorhandene Backup aus iCloud (falls vorhanden) und aktualisiert den Status.
    func loadAvailableBackup() async {
        do {
            let record = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord, Error>) in
                privateDatabase.fetch(withRecordID: backupRecordID) { record, error in
                    if let record = record {
                        continuation.resume(returning: record)
                    } else {
                        continuation.resume(throwing: error ?? BackupError.backupNotFound)
                    }
                }
            }
            if let backupDate = record["backupDate"] as? Date {
                lastBackupDate = backupDate
                lastBackupStatus = .available
            }
        } catch {
            lastBackupStatus = .notAvailable
        }
    }

    // MARK: - Automatische Backup-Funktionen

    func enableAutomaticBackups() {
        UserDefaults.standard.set(true, forKey: "automaticBackupsEnabled")
        scheduleNextAutomaticBackup()
    }

    func disableAutomaticBackups() {
        UserDefaults.standard.set(false, forKey: "automaticBackupsEnabled")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["autoBackupReminder"])
    }

    var isAutomaticBackupEnabled: Bool {
        UserDefaults.standard.bool(forKey: "automaticBackupsEnabled")
    }

    private func scheduleNextAutomaticBackup() {
        Task {
            guard let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]),
                  granted else { return }

            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["autoBackupReminder"])
            var components = DateComponents()
            components.hour = 2
            components.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let content = UNMutableNotificationContent()
            content.title = "Automatisches Backup"
            content.body = "Deine Vanity Expense Logbook Daten werden jetzt gesichert"
            content.sound = UNNotificationSound.default
            content.userInfo = ["actionType": "autoBackup"]
            let request = UNNotificationRequest(identifier: "autoBackupReminder", content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
