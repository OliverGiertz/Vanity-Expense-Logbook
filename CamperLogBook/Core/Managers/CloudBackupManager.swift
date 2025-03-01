import Foundation
import CoreData
import CloudKit
import UIKit
import SwiftUI

/// Hauptklasse zur Verwaltung von iCloud-Backups
class CloudBackupManager: ObservableObject {
    static let shared = CloudBackupManager()
    
    // CloudKit constants
    private lazy var container: CKContainer = {
        return CKContainer.default()
    }()
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    private let recordType = "ExpenseBackup"
    private let backupMetadataID = "backupMetadata"
    
    // Backup status
    @Published var isBackupInProgress = false
    @Published var isRestoreInProgress = false
    @Published var backupProgress: Double = 0.0
    @Published var restoreProgress: Double = 0.0
    @Published var lastBackupDate: Date?
    @Published var lastBackupStatus: BackupStatus = .none
    @Published var lastErrorMessage: String?
    
    // App version und Dateninformationen
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var coreDataCoordinator: CoreDataBackupCoordinator?
    private var receiptCoordinator: ReceiptBackupCoordinator?
    
    // Flag um zu prüfen, ob CloudKit initialisiert und verfügbar ist
    private var isCloudKitAvailable = false
    
    private init() {
        // Verzögerte Initialisierung von CloudKit im Debug-Modus
        #if DEBUG
        // Im Debug-Modus verzögern wir die CloudKit-Initialisierung,
        // um die Fehlermeldung zu vermeiden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.initializeCloudKit()
        }
        #else
        initializeCloudKit()
        #endif
    }
    
    private func initializeCloudKit() {
        // Prüfe, ob CloudKit verfügbar ist
        container.accountStatus { [weak self] (status, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isCloudKitAvailable = (status == .available && error == nil)
                
                if self.isCloudKitAvailable {
                    self.checkBackupMetadata()
                } else {
                    self.lastBackupStatus = .notAvailable
                    if let error = error {
                        self.lastErrorMessage = "iCloud nicht verfügbar: \(error.localizedDescription)"
                    } else {
                        self.lastErrorMessage = "iCloud nicht verfügbar. Bitte in den Einstellungen aktivieren."
                    }
                }
            }
        }
    }
    
    /// Stellt eine Verbindung zu CoreData her, um Backup-Operationen durchzuführen
    func connect(to context: NSManagedObjectContext) {
        self.coreDataCoordinator = CoreDataBackupCoordinator(context: context)
        self.receiptCoordinator = ReceiptBackupCoordinator(context: context)
    }
    
    /// Überprüft, ob der Benutzer iCloud aktiviert hat
    func checkiCloudAvailability(completion: @escaping (Bool) -> Void) {
        // Falls CloudKit noch nicht initialisiert wurde, sofort mit false antworten
        if !isCloudKitAvailable {
            DispatchQueue.main.async {
                completion(false)
            }
            return
        }
        
        container.accountStatus { [weak self] (status, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.lastErrorMessage = "iCloud Fehler: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                switch status {
                case .available:
                    completion(true)
                default:
                    self?.lastErrorMessage = "iCloud nicht verfügbar. Bitte in den Einstellungen aktivieren."
                    completion(false)
                }
            }
        }
    }
    
    /// Prüft, ob ein Backup in der Cloud existiert und lädt Metadaten
    func checkBackupMetadata() {
        // Falls CloudKit noch nicht initialisiert wurde, abbrechen
        if !isCloudKitAvailable { return }
        
        checkiCloudAvailability { [weak self] available in
            guard let self = self, available else { return }
            
            let predicate = NSPredicate(format: "recordID.recordName == %@", self.backupMetadataID)
            let query = CKQuery(recordType: self.recordType, predicate: predicate)
            
            self.privateDatabase.perform(query, inZoneWith: nil) { [weak self] records, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.lastErrorMessage = "Fehler beim Laden der Backup-Metadaten: \(error.localizedDescription)"
                        self.lastBackupStatus = .error
                        return
                    }
                    
                    if let record = records?.first {
                        if let timestamp = record["lastBackupDate"] as? Date {
                            self.lastBackupDate = timestamp
                            self.lastBackupStatus = .available
                        }
                    } else {
                        self.lastBackupStatus = .notAvailable
                    }
                }
            }
        }
    }
    
    /// Erstellt ein Backup aller App-Daten in iCloud
    func createBackup(completion: @escaping (Bool, String?) -> Void) {
        // Falls CloudKit noch nicht initialisiert wurde, mit Fehler abbrechen
        if !isCloudKitAvailable {
            completion(false, "iCloud nicht verfügbar")
            return
        }
        
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            completion(false, "Backup-System nicht initialisiert")
            return
        }
        
        checkiCloudAvailability { [weak self] available in
            guard let self = self, available else {
                completion(false, "iCloud nicht verfügbar")
                return
            }
            
            DispatchQueue.main.async {
                self.isBackupInProgress = true
                self.backupProgress = 0.0
                self.lastErrorMessage = nil
            }
            
            // 1. Erstelle temporäre Dateien für das Backup
            let tempBackupURL = self.createTempDirectory()
            let coreDataURL = tempBackupURL.appendingPathComponent("coredata_backup.sqlite")
            let receiptsURL = tempBackupURL.appendingPathComponent("receipts")
            
            do {
                try FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
                
                // 2. Backup CoreData
                coreDataCoordinator.exportStore(to: coreDataURL) { [weak self] success, error in
                    if !success {
                        DispatchQueue.main.async {
                            self?.isBackupInProgress = false
                            self?.lastErrorMessage = "CoreData Backup fehlgeschlagen: \(error ?? "Unbekannter Fehler")"
                            self?.lastBackupStatus = .error
                            completion(false, self?.lastErrorMessage)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.backupProgress = 0.3
                    }
                    
                    // 3. Backup Belege (PDF/Bilder)
                    receiptCoordinator.exportReceipts(to: receiptsURL) { [weak self] success, receiptCount, error in
                        if !success {
                            DispatchQueue.main.async {
                                self?.isBackupInProgress = false
                                self?.lastErrorMessage = "Beleg-Backup fehlgeschlagen: \(error ?? "Unbekannter Fehler")"
                                self?.lastBackupStatus = .error
                                completion(false, self?.lastErrorMessage)
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self?.backupProgress = 0.6
                        }
                        
                        // 4. Erstelle ZIP-Archiv (vereinfacht durch Kopie der Dateien)
                        let backupPackage = tempBackupURL.appendingPathComponent("backup_package")
                        
                        do {
                            try FileManager.default.createDirectory(at: backupPackage, withIntermediateDirectories: true)
                            
                            // Kopiere Version-Info-Datei
                            let versionInfoPath = tempBackupURL.appendingPathComponent("version.plist")
                            let versionInfoDestPath = backupPackage.appendingPathComponent("version.plist")
                            try FileManager.default.copyItem(at: versionInfoPath, to: versionInfoDestPath)
                            
                            // Kopiere CoreData-Backup
                            let coreDataDestPath = backupPackage.appendingPathComponent("coredata_backup.sqlite")
                            try FileManager.default.copyItem(at: coreDataURL, to: coreDataDestPath)
                            
                            // Kopiere Belege in einen Unterordner
                            let receiptsDestPath = backupPackage.appendingPathComponent("receipts")
                            try FileManager.default.createDirectory(at: receiptsDestPath, withIntermediateDirectories: true)
                            
                            let receiptFiles = try FileManager.default.contentsOfDirectory(at: receiptsURL, includingPropertiesForKeys: nil)
                            for fileURL in receiptFiles {
                                let fileName = fileURL.lastPathComponent
                                let destURL = receiptsDestPath.appendingPathComponent(fileName)
                                try FileManager.default.copyItem(at: fileURL, to: destURL)
                            }
                            
                            DispatchQueue.main.async {
                                self?.backupProgress = 0.7
                            }
                            
                            // 5. Upload zur iCloud
                            self?.uploadBackupToCloud(backupPackage: backupPackage, receiptCount: receiptCount) { success, error in
                                DispatchQueue.main.async {
                                    self?.isBackupInProgress = false
                                    if success {
                                        self?.lastBackupDate = Date()
                                        self?.lastBackupStatus = .available
                                        self?.backupProgress = 1.0
                                        completion(true, nil)
                                    } else {
                                        self?.lastErrorMessage = "Upload fehlgeschlagen: \(error ?? "Unbekannter Fehler")"
                                        self?.lastBackupStatus = .error
                                        completion(false, self?.lastErrorMessage)
                                    }
                                    
                                    // Lösche temporäre Dateien
                                    try? FileManager.default.removeItem(at: tempBackupURL)
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self?.isBackupInProgress = false
                                self?.lastErrorMessage = "Backup-Paket-Erstellung fehlgeschlagen: \(error.localizedDescription)"
                                self?.lastBackupStatus = .error
                                completion(false, self?.lastErrorMessage)
                                try? FileManager.default.removeItem(at: tempBackupURL)
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isBackupInProgress = false
                    self.lastErrorMessage = "Backup-Vorbereitung fehlgeschlagen: \(error.localizedDescription)"
                    self.lastBackupStatus = .error
                    completion(false, self.lastErrorMessage)
                }
            }
        }
    }
    
    /// Stellt ein Backup wieder her
    func restoreBackup(completion: @escaping (Bool, String?) -> Void) {
        // Falls CloudKit noch nicht initialisiert wurde, mit Fehler abbrechen
        if !isCloudKitAvailable {
            completion(false, "iCloud nicht verfügbar")
            return
        }
        
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            completion(false, "Backup-System nicht initialisiert")
            return
        }
        
        checkiCloudAvailability { [weak self] available in
            guard let self = self, available else {
                completion(false, "iCloud nicht verfügbar")
                return
            }
            
            DispatchQueue.main.async {
                self.isRestoreInProgress = true
                self.restoreProgress = 0.0
                self.lastErrorMessage = nil
            }
            
            // 1. Lade Backup von iCloud
            self.downloadBackupFromCloud { [weak self] success, backupFolder, error in
                if !success {
                    DispatchQueue.main.async {
                        self?.isRestoreInProgress = false
                        self?.lastErrorMessage = "Download fehlgeschlagen: \(error ?? "Unbekannter Fehler")"
                        completion(false, self?.lastErrorMessage)
                    }
                    return
                }
                
                guard let backupFolder = backupFolder else {
                    DispatchQueue.main.async {
                        self?.isRestoreInProgress = false
                        self?.lastErrorMessage = "Keine Backup-Datei gefunden"
                        completion(false, self?.lastErrorMessage)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.restoreProgress = 0.3
                }
                
                // 2. Prüfe Version
                guard let isCompatible = self?.isBackupCompatible(backupFolder), isCompatible else {
                    DispatchQueue.main.async {
                        self?.isRestoreInProgress = false
                        self?.lastErrorMessage = "Backup ist nicht mit dieser App-Version kompatibel"
                        completion(false, self?.lastErrorMessage)
                        try? FileManager.default.removeItem(at: backupFolder)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.restoreProgress = 0.5
                }
                
                // 3. Importiere CoreData
                let coreDataFile = backupFolder.appendingPathComponent("coredata_backup.sqlite")
                coreDataCoordinator.importStore(from: coreDataFile) { [weak self] success, coreDataError in
                    if !success {
                        DispatchQueue.main.async {
                            self?.isRestoreInProgress = false
                            self?.lastErrorMessage = "CoreData-Import fehlgeschlagen: \(coreDataError ?? "Unbekannter Fehler")"
                            completion(false, self?.lastErrorMessage)
                            try? FileManager.default.removeItem(at: backupFolder)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.restoreProgress = 0.7
                    }
                    
                    // 4. Importiere Belege
                    let receiptsFolder = backupFolder.appendingPathComponent("receipts")
                    receiptCoordinator.importReceipts(from: receiptsFolder) { success, receiptError in
                        DispatchQueue.main.async {
                            self?.isRestoreInProgress = false
                            if success {
                                self?.restoreProgress = 1.0
                                completion(true, nil)
                            } else {
                                self?.lastErrorMessage = "Beleg-Import fehlgeschlagen: \(receiptError ?? "Unbekannter Fehler")"
                                completion(false, self?.lastErrorMessage)
                            }
                            // Lösche temporäre Dateien
                            try? FileManager.default.removeItem(at: backupFolder)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper-Methoden
    
    /// Lädt das Backup von iCloud herunter
    private func downloadBackupFromCloud(completion: @escaping (Bool, URL?, String?) -> Void) {
        let predicate = NSPredicate(format: "recordType == %@", "backupData")
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        privateDatabase.perform(query, inZoneWith: nil) { [weak self] records, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, nil, "Fehler beim Laden des Backups: \(error.localizedDescription)")
                }
                return
            }
            
            guard let record = records?.first else {
                DispatchQueue.main.async {
                    completion(false, nil, "Kein Backup gefunden")
                }
                return
            }
            
            if let asset = record["backupFolder"] as? CKAsset, let fileURL = asset.fileURL {
                let tempDir = self?.createTempDirectory()
                let extractionDir = tempDir?.appendingPathComponent("extracted_backup")
                
                do {
                    if let extractionDir = extractionDir {
                        try FileManager.default.createDirectory(at: extractionDir, withIntermediateDirectories: true)
                        
                        // Kopiere alle Dateien aus dem Asset-Ordner in den Extraktionsordner
                        let fileManager = FileManager.default
                        let backupFiles = try fileManager.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: nil)
                        
                        for file in backupFiles {
                            let destPath = extractionDir.appendingPathComponent(file.lastPathComponent)
                            try fileManager.copyItem(at: file, to: destPath)
                        }
                        
                        DispatchQueue.main.async {
                            completion(true, extractionDir, nil)
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(false, nil, "Konnte keinen temporären Ordner erstellen")
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(false, nil, "Fehler beim Extrahieren des Backups: \(error.localizedDescription)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, nil, "Backup-Datei ist beschädigt")
                }
            }
        }
    }
    
    /// Lädt das Backup in die iCloud hoch
    private func uploadBackupToCloud(backupPackage: URL, receiptCount: Int, completion: @escaping (Bool, String?) -> Void) {
        let dataRecord = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: "backupData"))
        
        // Füge Backup-Datei als Asset hinzu
        if FileManager.default.fileExists(atPath: backupPackage.path) {
            dataRecord["backupFolder"] = CKAsset(fileURL: backupPackage)
            dataRecord["appVersion"] = appVersion
            dataRecord["receiptCount"] = receiptCount
            dataRecord["creationDate"] = Date()
            
            // Füge Metadaten-Record hinzu oder aktualisiere bestehenden
            let metadataRecord = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: backupMetadataID))
            metadataRecord["lastBackupDate"] = Date()
            metadataRecord["appVersion"] = appVersion
            metadataRecord["receiptCount"] = receiptCount
            
            // Bereite Multi-Operation vor
            let saveOperation = CKModifyRecordsOperation(recordsToSave: [dataRecord, metadataRecord], recordIDsToDelete: nil)
            saveOperation.qualityOfService = .userInitiated
            
            // Progress-Updates
            var currentProgress: Double = 0.7
            saveOperation.perRecordProgressBlock = { [weak self] _, progress in
                DispatchQueue.main.async {
                    // Skaliere Fortschritt von 0.7 bis 1.0
                    currentProgress = 0.7 + (Double(progress) * 0.3)
                    self?.backupProgress = min(0.99, currentProgress) // Nicht ganz 1.0 bis zur vollständigen Fertigstellung
                }
            }
            
            saveOperation.modifyRecordsCompletionBlock = { records, _, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "Upload-Fehler: \(error.localizedDescription)")
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            }
            
            privateDatabase.add(saveOperation)
        } else {
            DispatchQueue.main.async {
                completion(false, "Backup-Datei nicht gefunden")
            }
        }
    }
    
    /// Erstellt ein temporäres Verzeichnis für Backup-Operationen
    private func createTempDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
    
    /// Prüft, ob ein Backup mit der aktuellen App-Version kompatibel ist
    private func isBackupCompatible(_ backupDir: URL) -> Bool {
        // In diesem Fall betrachten wir nur die Hauptversionsnummer
        // Format: 1.2.3 -> 1 ist die Hauptversion
        let versionInfoPath = backupDir.appendingPathComponent("version.plist")
        
        // Wenn keine Versionsdatei existiert, nehmen wir an, dass das Backup inkompatibel ist
        guard FileManager.default.fileExists(atPath: versionInfoPath.path),
              let versionData = try? Data(contentsOf: versionInfoPath),
              let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, options: [], format: nil) as? [String: Any],
              let backupVersion = versionInfo["appVersion"] as? String else {
            return false
        }
        
        // Extrahiere Hauptversion aus Backup- und aktueller App-Version
        let currentMajorVersion = appVersion.split(separator: ".").first ?? ""
        let backupMajorVersion = backupVersion.split(separator: ".").first ?? ""
        
        return currentMajorVersion == backupMajorVersion
    }
    
    // Aktiviert tägliche automatische Backups
    func enableAutomaticBackups() {
        UserDefaults.standard.set(true, forKey: "automaticBackupsEnabled")
        scheduleNextAutomaticBackup()
    }
    
    // Deaktiviert tägliche automatische Backups
    func disableAutomaticBackups() {
        UserDefaults.standard.set(false, forKey: "automaticBackupsEnabled")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["autoBackupReminder"])
    }
    
    // Ist automatisches Backup aktiviert?
    var isAutomaticBackupEnabled: Bool {
        UserDefaults.standard.bool(forKey: "automaticBackupsEnabled")
    }
    
    // Plant das nächste automatische Backup
    private func scheduleNextAutomaticBackup() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                // Lösche vorherige Benachrichtigungen
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["autoBackupReminder"])
                
                // Setze einen täglichen Trigger für das Backup (z.B. um 2 Uhr nachts)
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

// MARK: - Backup Status Enum
extension CloudBackupManager {
    enum BackupStatus {
        case none
        case notAvailable
        case available
        case inProgress
        case error
    }
}
