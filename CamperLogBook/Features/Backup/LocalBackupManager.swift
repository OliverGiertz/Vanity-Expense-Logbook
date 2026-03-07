import Foundation
import CoreData
import UIKit
import SwiftUI
import UserNotifications

/// Fehlertypen für Backup-Operationen
enum BackupError: LocalizedError {
    case notInitialized
    case directoryError
    case backupNotFound
    case invalidFormat
    case incompatibleVersion
    case missingCoreDataBackup
    case noAsset

    var errorDescription: String? {
        switch self {
        case .notInitialized: return "Backup-System nicht initialisiert"
        case .directoryError: return "Backup-Verzeichnis konnte nicht erstellt werden"
        case .backupNotFound: return "Backup nicht gefunden"
        case .invalidFormat: return "Ungültiges Backup-Format oder fehlende Versionsinformationen"
        case .incompatibleVersion: return "Das Backup ist nicht mit dieser App-Version kompatibel"
        case .missingCoreDataBackup: return "CoreData-Backup nicht gefunden"
        case .noAsset: return "Kein Backup-Asset in iCloud gefunden"
        }
    }
}

/// Hauptklasse zur Verwaltung von lokalen Backups
@MainActor
class LocalBackupManager: ObservableObject {
    static let shared = LocalBackupManager()

    // Backup status
    @Published var isBackupInProgress = false
    @Published var isRestoreInProgress = false
    @Published var backupProgress: Double = 0.0
    @Published var restoreProgress: Double = 0.0
    @Published var lastBackupDate: Date?
    @Published var lastBackupStatus: BackupStatus = .none
    @Published var lastErrorMessage: String?
    @Published var availableBackups: [BackupInfo] = []

    // App version und Dateninformationen
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    // App-Name für Backup-Verzeichnis
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ??
        "CamperLogBook"
    }

    // Backup-Verzeichnis im Documents-Verzeichnis
    private var backupDirectoryURL: URL? {
        let fm = FileManager.default
        guard let documentDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let backupDir = documentDir.appendingPathComponent("\(appName) Backups")
        if !fm.fileExists(atPath: backupDir.path) {
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Erstellen des Backup-Verzeichnisses")
            }
        }
        return backupDir
    }

    private var coreDataCoordinator: CoreDataBackupCoordinator?
    private var receiptCoordinator: ReceiptBackupCoordinator?

    private init() {
        loadAvailableBackups()
    }

    /// Stellt eine Verbindung zu CoreData her, um Backup-Operationen durchzuführen
    func connect(to context: NSManagedObjectContext) {
        self.coreDataCoordinator = CoreDataBackupCoordinator(context: context)
        self.receiptCoordinator = ReceiptBackupCoordinator(context: context)
    }

    /// Lädt die verfügbaren Backups (synchron, lightweight Verzeichnis-Listing)
    func loadAvailableBackups() {
        guard let backupDir = backupDirectoryURL else {
            availableBackups = []
            lastBackupStatus = .notAvailable
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey])
            var backups: [BackupInfo] = []

            for item in contents where item.lastPathComponent.hasPrefix("backup_") && item.pathExtension.lowercased() == "zip" {
                let attrs = try FileManager.default.attributesOfItem(atPath: item.path)
                let creationDate = attrs[.creationDate] as? Date ?? Date()
                let backupID = item.deletingPathExtension().lastPathComponent
                var version = appVersion
                if let versionInfo = extractVersionFromZip(at: item) {
                    version = versionInfo
                }
                backups.append(BackupInfo(id: backupID, date: creationDate, version: version, path: item))
            }

            backups.sort { $0.date > $1.date }
            availableBackups = backups
            lastBackupStatus = backups.isEmpty ? .notAvailable : .available
            lastBackupDate = backups.first?.date
        } catch {
            availableBackups = []
            lastBackupStatus = .error
            lastErrorMessage = "Fehler beim Laden der Backups: \(error.localizedDescription)"
        }
    }

    // MARK: - Backup-Operationen

    /// Erstellt ein Backup aller App-Daten
    func createBackup() async throws {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            throw BackupError.notInitialized
        }
        guard let backupDir = backupDirectoryURL else {
            throw BackupError.directoryError
        }

        isBackupInProgress = true
        backupProgress = 0.0
        lastErrorMessage = nil
        lastBackupStatus = .inProgress

        defer { isBackupInProgress = false }

        let timestamp = Int(Date().timeIntervalSince1970)
        let backupID = "backup_\(timestamp)"
        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(backupID)

        defer { try? FileManager.default.removeItem(at: tempDirURL) }

        if FileManager.default.fileExists(atPath: tempDirURL.path) {
            try FileManager.default.removeItem(at: tempDirURL)
        }
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)

        // Schritt 1: CoreData exportieren
        let coreDataURL = tempDirURL.appendingPathComponent("coredata_backup.sqlite")
        try await coreDataCoordinator.exportStore(to: coreDataURL)
        backupProgress = 0.3

        // Schritt 2: Belege exportieren
        let receiptsURL = tempDirURL.appendingPathComponent("receipts")
        try? FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
        let receiptCount = try await receiptCoordinator.exportReceipts(to: receiptsURL)
        backupProgress = 0.6

        // Schritt 3: Versionsinfo erstellen
        let versionInfo: [String: Any] = [
            "appVersion": appVersion,
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            "backupDate": Date(),
            "receiptCount": receiptCount
        ]
        let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
        try versionData.write(to: tempDirURL.appendingPathComponent("version.plist"))

        let infoContent = "timestamp: \(timestamp)\ndate: \(Date())\n"
        try infoContent.write(to: tempDirURL.appendingPathComponent("backup.info"), atomically: true, encoding: .utf8)

        // Schritt 4: In Backup-Verzeichnis kopieren
        let backupFolderURL = backupDir.appendingPathComponent(backupID)
        try FileManager.default.copyItem(at: tempDirURL, to: backupFolderURL)

        // Schritt 5: ZIP erstellen
        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        try FileManager.default.zipItem(at: backupFolderURL, to: zipURL)

        // Schritt 6: Unkomprimierten Ordner löschen
        try FileManager.default.removeItem(at: backupFolderURL)

        backupProgress = 1.0
        lastBackupDate = Date()
        lastBackupStatus = .available
        loadAvailableBackups()
    }

    /// Stellt ein Backup wieder her
    func restoreBackup(backupID: String) async throws {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            throw BackupError.notInitialized
        }
        guard let backupDir = backupDirectoryURL else {
            throw BackupError.directoryError
        }

        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw BackupError.backupNotFound
        }

        isRestoreInProgress = true
        restoreProgress = 0.0
        lastErrorMessage = nil

        defer { isRestoreInProgress = false }

        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("restore_\(backupID)")
        defer { try? FileManager.default.removeItem(at: tempDirURL) }

        if FileManager.default.fileExists(atPath: tempDirURL.path) {
            try FileManager.default.removeItem(at: tempDirURL)
        }
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipURL, to: tempDirURL)

        restoreProgress = 0.2

        let backupVersion = try readVersion(from: tempDirURL, fallbackZip: zipURL)
        guard isBackupVersionCompatible(backupVersion) else {
            throw BackupError.incompatibleVersion
        }

        let coreDataPath = tempDirURL.appendingPathComponent("coredata_backup.sqlite")
        guard FileManager.default.fileExists(atPath: coreDataPath.path) else {
            throw BackupError.missingCoreDataBackup
        }

        try coreDataCoordinator.importStore(from: coreDataPath)
        restoreProgress = 0.7

        let receiptsDir = tempDirURL.appendingPathComponent("receipts")
        try await receiptCoordinator.importReceipts(from: receiptsDir)

        restoreProgress = 1.0
    }

    /// Importiert ein Backup von einem vom User ausgewählten ZIP
    func importBackup(from zipURL: URL) async throws {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            throw BackupError.notInitialized
        }
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw BackupError.backupNotFound
        }

        isRestoreInProgress = true
        restoreProgress = 0.0
        lastErrorMessage = nil

        defer { isRestoreInProgress = false }

        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("import_\(Int(Date().timeIntervalSince1970))")
        defer { try? FileManager.default.removeItem(at: tempDirURL) }

        if FileManager.default.fileExists(atPath: tempDirURL.path) {
            try FileManager.default.removeItem(at: tempDirURL)
        }
        try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipURL, to: tempDirURL)

        restoreProgress = 0.2

        let backupVersion = try readVersion(from: tempDirURL, fallbackZip: zipURL)
        guard isBackupVersionCompatible(backupVersion) else {
            throw BackupError.incompatibleVersion
        }

        let coreDataPath = tempDirURL.appendingPathComponent("coredata_backup.sqlite")
        guard FileManager.default.fileExists(atPath: coreDataPath.path) else {
            throw BackupError.missingCoreDataBackup
        }

        try coreDataCoordinator.importStore(from: coreDataPath)
        restoreProgress = 0.7

        let receiptsDir = tempDirURL.appendingPathComponent("receipts")
        try await receiptCoordinator.importReceipts(from: receiptsDir)

        restoreProgress = 1.0
        loadAvailableBackups()
    }

    /// Löscht ein Backup
    func deleteBackup(backupID: String) throws {
        guard let backupDir = backupDirectoryURL else {
            throw BackupError.directoryError
        }
        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw BackupError.backupNotFound
        }
        try FileManager.default.removeItem(at: zipURL)
        loadAvailableBackups()
    }

    /// Exportiert ein Backup zur Freigabe
    func exportBackup(backupID: String) throws -> URL {
        guard let backupDir = backupDirectoryURL else {
            throw BackupError.directoryError
        }
        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            throw BackupError.backupNotFound
        }
        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(backupID).zip")
        if FileManager.default.fileExists(atPath: tempZipURL.path) {
            try? FileManager.default.removeItem(at: tempZipURL)
        }
        try FileManager.default.copyItem(at: zipURL, to: tempZipURL)
        return tempZipURL
    }

    // MARK: - Automatische Backups

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

    /// Führt ein automatisches Backup durch, wenn es fällig ist (> 7 Tage seit letztem Auto-Backup).
    func performBackupIfDue() {
        guard isAutomaticBackupEnabled, coreDataCoordinator != nil, !isBackupInProgress else { return }

        let lastAutoBackup = UserDefaults.standard.object(forKey: "lastAutoBackupDate") as? Date
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        if let lastBackupDate = lastAutoBackup, lastBackupDate >= sevenDaysAgo { return }

        Task {
            do {
                try await createBackup()
                UserDefaults.standard.set(Date(), forKey: "lastAutoBackupDate")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
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

    // MARK: - Hilfsmethoden

    private func extractVersionFromZip(at zipURL: URL) -> String? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: zipURL, to: tempDir)
            let versionPath = tempDir.appendingPathComponent("version.plist")
            if FileManager.default.fileExists(atPath: versionPath.path),
               let versionData = try? Data(contentsOf: versionPath),
               let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
               let backupVersion = versionInfo["appVersion"] as? String {
                return backupVersion
            }
            let archiveData = try Data(contentsOf: zipURL)
            if let manifest = try ZipArchive.extractManifest(from: archiveData) {
                return manifest.version
            }
            return nil
        } catch {
            return nil
        }
    }

    private func readVersion(from tempDir: URL, fallbackZip: URL) throws -> String {
        let versionPath = tempDir.appendingPathComponent("version.plist")
        if FileManager.default.fileExists(atPath: versionPath.path),
           let versionData = try? Data(contentsOf: versionPath),
           let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
           let version = versionInfo["appVersion"] as? String {
            return version
        }
        let archiveData = try Data(contentsOf: fallbackZip)
        if let manifest = try ZipArchive.extractManifest(from: archiveData) {
            return manifest.version
        }
        throw BackupError.invalidFormat
    }

    private func isBackupVersionCompatible(_ backupVersion: String) -> Bool {
        let currentMajorVersion = appVersion.split(separator: ".").first ?? ""
        let backupMajorVersion = backupVersion.split(separator: ".").first ?? ""
        return currentMajorVersion == backupMajorVersion
    }
}

// MARK: - Backup Status Enum und BackupInfo

extension LocalBackupManager {
    enum BackupStatus {
        case none
        case notAvailable
        case available
        case inProgress
        case error
    }

    struct BackupInfo: Identifiable {
        let id: String
        let date: Date
        let version: String
        let path: URL
    }
}
