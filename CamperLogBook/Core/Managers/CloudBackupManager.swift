import Foundation
import CloudKit
import CoreData
import UIKit

/// Verwalter für iCloud-Backups der App.
/// Sichert CoreData-Store, Belege und Versionsinformationen als ZIP‑Archiv in iCloud.
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
        // Standard iCloud-Container
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        // Prüfe den iCloud-Accountstatus
        checkiCloudAccountStatus()
    }
    
    /// Verbindet die Backup-Komponenten mit dem CoreData-Kontext
    func connect(to context: NSManagedObjectContext) {
        self.coreDataCoordinator = CoreDataBackupCoordinator(context: context)
        self.receiptCoordinator = ReceiptBackupCoordinator(context: context)
    }
    
    /// Prüft den iCloud-Accountstatus und lädt vorhandenes Backup, falls vorhanden
    private func checkiCloudAccountStatus() {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                if status == .available {
                    self.loadAvailableBackup()
                } else {
                    self.lastBackupStatus = .notAvailable
                    switch status {
                    case .noAccount:
                        self.lastErrorMessage = "Kein iCloud-Account angemeldet. Bitte in den Einstellungen bei iCloud anmelden."
                    case .restricted:
                        self.lastErrorMessage = "iCloud ist eingeschränkt. Bitte überprüfe die iCloud-Einstellungen."
                    case .couldNotDetermine:
                        self.lastErrorMessage = "Der iCloud-Status konnte nicht ermittelt werden."
                    default:
                        self.lastErrorMessage = error?.localizedDescription ?? "iCloud ist nicht verfügbar."
                    }
                }
            }
        }
    }
    
    /// Erstellt ein Backup der App-Daten und lädt es in iCloud hoch.
    func createBackup(completion: @escaping (Bool, String?) -> Void) {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            completion(false, "Backup system not initialized")
            return
        }
        
        isBackupInProgress = true
        backupProgress = 0.0
        lastErrorMessage = nil
        
        // Erstelle ein temporäres Verzeichnis
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            isBackupInProgress = false
            completion(false, "Failed to create temporary directory: \(error.localizedDescription)")
            return
        }
        
        // Pfade für CoreData und Belege
        let coreDataURL = tempDir.appendingPathComponent("coredata_backup.sqlite")
        let receiptsURL = tempDir.appendingPathComponent("receipts")
        try? FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
        
        // Schritt 1: Exportiere CoreData
        coreDataCoordinator.exportStore(to: coreDataURL) { [weak self] success, errorString in
            guard let self = self else { return }
            if !success {
                DispatchQueue.main.async {
                    self.isBackupInProgress = false
                    completion(false, "CoreData export failed: \(errorString ?? "unknown error")")
                }
                return
            }
            DispatchQueue.main.async { self.backupProgress = 0.3 }
            
            // Schritt 2: Exportiere Belege
            receiptCoordinator.exportReceipts(to: receiptsURL) { [weak self] success, receiptCount, errorString in
                guard let self = self else { return }
                if !success {
                    DispatchQueue.main.async {
                        self.isBackupInProgress = false
                        completion(false, "Receipts export failed: \(errorString ?? "unknown error")")
                    }
                    return
                }
                DispatchQueue.main.async { self.backupProgress = 0.6 }
                
                // Schritt 3: Schreibe Versionsinformationen
                let versionInfoPath = tempDir.appendingPathComponent("version.plist")
                let versionInfo: [String: Any] = [
                    "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                    "backupDate": Date(),
                    "receiptCount": receiptCount
                ]
                do {
                    let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
                    try versionData.write(to: versionInfoPath)
                } catch {
                    DispatchQueue.main.async {
                        self.isBackupInProgress = false
                        completion(false, "Failed to write version info: \(error.localizedDescription)")
                    }
                    return
                }
                
                // Schritt 4: Erstelle ein ZIP-Archiv aus dem temporären Verzeichnis
                let zipURL = tempDir.deletingLastPathComponent().appendingPathComponent("backup.zip")
                do {
                    try FileManager.default.zipItem(at: tempDir, to: zipURL)
                } catch {
                    DispatchQueue.main.async {
                        self.isBackupInProgress = false
                        completion(false, "Failed to create ZIP archive: \(error.localizedDescription)")
                    }
                    return
                }
                DispatchQueue.main.async { self.backupProgress = 0.8 }
                
                // Schritt 5: Lade das ZIP-Archiv in iCloud hoch
                self.uploadBackup(zipURL: zipURL) { success, errorString in
                    try? FileManager.default.removeItem(at: tempDir)
                    DispatchQueue.main.async {
                        self.isBackupInProgress = false
                        if success {
                            self.backupProgress = 1.0
                            self.lastBackupDate = Date()
                            self.lastBackupStatus = .available
                        } else {
                            self.lastBackupStatus = .error
                        }
                        completion(success, errorString)
                    }
                }
            }
        }
    }
    
    /// Lädt das ZIP-Archiv als CKAsset in iCloud hoch.
    private func uploadBackup(zipURL: URL, completion: @escaping (Bool, String?) -> Void) {
        let record = CKRecord(recordType: recordType, recordID: backupRecordID)
        record["backupDate"] = Date() as CKRecordValue
        record["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String as CKRecordValue?
        record["backupAsset"] = CKAsset(fileURL: zipURL)
        
        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOp.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let error = error {
                completion(false, "Cloud upload failed: \(error.localizedDescription)")
            } else {
                completion(true, nil)
            }
        }
        modifyOp.qualityOfService = .userInitiated
        privateDatabase.add(modifyOp)
    }
    
    /// Stellt ein Backup aus iCloud wieder her.
    func restoreBackup(completion: @escaping (Bool, String?) -> Void) {
        isRestoreInProgress = true
        restoreProgress = 0.0
        lastErrorMessage = nil
        
        // Hole das Backup-Record aus iCloud
        privateDatabase.fetch(withRecordID: backupRecordID) { [weak self] record, error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async {
                    self.isRestoreInProgress = false
                    completion(false, "Failed to fetch backup from iCloud: \(error.localizedDescription)")
                }
                return
            }
            guard let record = record,
                  let asset = record["backupAsset"] as? CKAsset,
                  let fileURL = asset.fileURL else {
                DispatchQueue.main.async {
                    self.isRestoreInProgress = false
                    completion(false, "No backup asset found in iCloud record.")
                }
                return
            }
            DispatchQueue.main.async { self.restoreProgress = 0.3 }
            
            // Entpacke das heruntergeladene ZIP in ein temporäres Verzeichnis
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                try FileManager.default.unzipItem(at: fileURL, to: tempDir)
            } catch {
                DispatchQueue.main.async {
                    self.isRestoreInProgress = false
                    completion(false, "Failed to unzip backup: \(error.localizedDescription)")
                }
                return
            }
            DispatchQueue.main.async { self.restoreProgress = 0.6 }
            
            // Stelle CoreData und Belege wieder her
            let coreDataURL = tempDir.appendingPathComponent("coredata_backup.sqlite")
            guard FileManager.default.fileExists(atPath: coreDataURL.path) else {
                DispatchQueue.main.async {
                    self.isRestoreInProgress = false
                    completion(false, "CoreData backup file not found in unzipped data.")
                }
                return
            }
            self.coreDataCoordinator?.importStore(from: coreDataURL) { [weak self] success, errorString in
                guard let self = self else { return }
                if !success {
                    DispatchQueue.main.async {
                        self.isRestoreInProgress = false
                        completion(false, "Failed to import CoreData store: \(errorString ?? "unknown error")")
                    }
                    return
                }
                DispatchQueue.main.async { self.restoreProgress = 0.8 }
                let receiptsURL = tempDir.appendingPathComponent("receipts")
                self.receiptCoordinator?.importReceipts(from: receiptsURL) { [weak self] success, errorString in
                    guard let self = self else { return }
                    try? FileManager.default.removeItem(at: tempDir)
                    DispatchQueue.main.async {
                        self.isRestoreInProgress = false
                        if success {
                            self.restoreProgress = 1.0
                            completion(true, nil)
                        } else {
                            completion(false, "Failed to import receipts: \(errorString ?? "unknown error")")
                        }
                    }
                }
            }
        }
    }
    
    /// Lädt das vorhandene Backup aus iCloud (falls vorhanden) und aktualisiert den Status.
    func loadAvailableBackup() {
        privateDatabase.fetch(withRecordID: backupRecordID) { [weak self] record, error in
            DispatchQueue.main.async {
                if let record = record, let backupDate = record["backupDate"] as? Date {
                    self?.lastBackupDate = backupDate
                    self?.lastBackupStatus = .available
                } else {
                    self?.lastBackupStatus = .notAvailable
                }
            }
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
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
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
}
