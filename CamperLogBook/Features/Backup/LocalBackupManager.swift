import Foundation
import CoreData
import UIKit
import SwiftUI

/// Hauptklasse zur Verwaltung von lokalen Backups
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
    
    // Backup Verzeichnis, sichtbar in der Dateien-App
    private var backupDirectoryURL: URL? {
        let fm = FileManager.default
        guard let documentDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let backupDir = documentDir.appendingPathComponent("\(appName) Backups")
        if !fm.fileExists(atPath: backupDir.path) {
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)
                var backupDirURL = backupDir
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try backupDirURL.setResourceValues(resourceValues)
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
    
    /// Lädt die verfügbaren Backups
    func loadAvailableBackups() {
        guard let backupDir = backupDirectoryURL else {
            DispatchQueue.main.async {
                self.availableBackups = []
                self.lastBackupStatus = .notAvailable
            }
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey])
            
            var backups: [BackupInfo] = []
            for item in contents {
                // Wir betrachten nur Ordner, die mit "backup_" beginnen
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir),
                   isDir.boolValue,
                   item.lastPathComponent.hasPrefix("backup_") {
                    
                    let attrs = try FileManager.default.attributesOfItem(atPath: item.path)
                    let creationDate = attrs[.creationDate] as? Date ?? Date()
                    
                    let backupID = item.lastPathComponent
                    
                    // Versuche Version zu lesen, falls vorhanden
                    var version = appVersion // Standardwert
                    let versionPath = item.appendingPathComponent("version.plist")
                    
                    if FileManager.default.fileExists(atPath: versionPath.path),
                       let versionData = try? Data(contentsOf: versionPath),
                       let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
                       let backupVersion = versionInfo["appVersion"] as? String {
                        version = backupVersion
                    }
                    
                    backups.append(BackupInfo(
                        id: backupID,
                        date: creationDate,
                        version: version,
                        path: item
                    ))
                }
            }
            
            // Nach Datum sortieren (neueste zuerst)
            backups.sort { $0.date > $1.date }
            
            DispatchQueue.main.async {
                self.availableBackups = backups
                self.lastBackupStatus = backups.isEmpty ? .notAvailable : .available
                self.lastBackupDate = backups.first?.date
            }
        } catch {
            DispatchQueue.main.async {
                self.availableBackups = []
                self.lastBackupStatus = .error
                self.lastErrorMessage = "Fehler beim Laden der Backups: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Backup-Operationen
    
    /// Erstellt ein Backup aller App-Daten
    func createBackup(completion: @escaping (Bool, String?) -> Void) {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            completion(false, "Backup-System nicht initialisiert")
            return
        }
        
        guard let backupDir = backupDirectoryURL else {
            completion(false, "Backup-Verzeichnis konnte nicht erstellt werden")
            return
        }
        
        // Status aktualisieren
        DispatchQueue.main.async {
            self.isBackupInProgress = true
            self.backupProgress = 0.0
            self.lastErrorMessage = nil
            self.lastBackupStatus = .inProgress
        }
        
        // Einen Zeitstempel zur eindeutigen Identifizierung des Backups erstellen
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupID = "backup_\(timestamp)"
        
        // Erstelle ein neues Backup-Verzeichnis
        let backupFolderURL = backupDir.appendingPathComponent(backupID)
        
        do {
            // Backup-Verzeichnis erstellen
            try FileManager.default.createDirectory(at: backupFolderURL, withIntermediateDirectories: true)
            
            // CoreData-Backup im Backup-Verzeichnis
            let coreDataURL = backupFolderURL.appendingPathComponent("coredata_backup.sqlite")
            
            // Schritt 1: CoreData exportieren
            coreDataCoordinator.exportStore(to: coreDataURL) { [weak self] success, error in
                guard let self = self else { return }
                
                if !success {
                    self.finishBackup(success: false, error: error, tempDir: backupFolderURL, completion: completion)
                    return
                }
                
                DispatchQueue.main.async {
                    self.backupProgress = 0.3
                }
                
                // Schritt 2: Belege exportieren
                let receiptsURL = backupFolderURL.appendingPathComponent("receipts")
                try? FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
                
                receiptCoordinator.exportReceipts(to: receiptsURL) { [weak self] success, receiptCount, error in
                    guard let self = self else { return }
                    
                    if !success {
                        self.finishBackup(success: false, error: error, tempDir: backupFolderURL, completion: completion)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.backupProgress = 0.6
                    }
                    
                    // Schritt 3: Version.plist erstellen
                    let versionInfoPath = backupFolderURL.appendingPathComponent("version.plist")
                    let versionInfo: [String: Any] = [
                        "appVersion": self.appVersion,
                        "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                        "backupDate": Date(),
                        "receiptCount": receiptCount
                    ]
                    
                    do {
                        let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
                        try versionData.write(to: versionInfoPath)
                        
                        // Schritt 4: Eine Backup-Info-Datei erstellen
                        let infoPath = backupFolderURL.appendingPathComponent("backup.info")
                        let infoContent = "timestamp: \(timestamp)\ndate: \(Date())\n"
                        try infoContent.write(to: infoPath, atomically: true, encoding: .utf8)
                        
                        // Backup erfolgreich erstellt
                        DispatchQueue.main.async {
                            self.backupProgress = 1.0
                            self.lastBackupDate = Date()
                            self.lastBackupStatus = .available
                            self.loadAvailableBackups()
                            completion(true, nil)
                        }
                    } catch {
                        self.finishBackup(success: false, error: "Fehler beim Erstellen der Versionsdatei: \(error.localizedDescription)", tempDir: backupFolderURL, completion: completion)
                    }
                }
            }
        } catch {
            finishBackup(success: false, error: "Fehler bei der Backup-Vorbereitung: \(error.localizedDescription)", tempDir: backupFolderURL, completion: completion)
        }
    }
    
    /// Stellt ein Backup wieder her
    func restoreBackup(backupID: String, completion: @escaping (Bool, String?) -> Void) {
        guard let coreDataCoordinator = coreDataCoordinator,
              let receiptCoordinator = receiptCoordinator else {
            completion(false, "Backup-System nicht initialisiert")
            return
        }
        
        guard let backupDir = backupDirectoryURL else {
            completion(false, "Backup-Verzeichnis nicht gefunden")
            return
        }
        
        // Pfad zum Backup-Verzeichnis
        let backupFolderURL = backupDir.appendingPathComponent(backupID)
        
        if !FileManager.default.fileExists(atPath: backupFolderURL.path) {
            completion(false, "Backup nicht gefunden")
            return
        }
        
        // Status aktualisieren
        DispatchQueue.main.async {
            self.isRestoreInProgress = true
            self.restoreProgress = 0.0
            self.lastErrorMessage = nil
        }
        
        // Logge den Inhalt des Backup-Verzeichnisses
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: backupFolderURL.path)
            ErrorLogger.shared.log(message: "Backup-Dateien: \(contents.joined(separator: ", "))")
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Auflisten der Backup-Dateien")
        }
        
        // Schritt 1: Versionsinformationen prüfen
        let versionPath = backupFolderURL.appendingPathComponent("version.plist")
        guard FileManager.default.fileExists(atPath: versionPath.path),
              let versionData = try? Data(contentsOf: versionPath),
              let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
              let backupVersion = versionInfo["appVersion"] as? String else {
            finishRestore(success: false, error: "Ungültiges Backup-Format oder fehlende Versionsinformationen", tempDir: backupFolderURL, completion: completion)
            return
        }
        
        // Prüfen, ob das Backup kompatibel ist
        let isCompatible = isBackupVersionCompatible(backupVersion)
        guard isCompatible else {
            finishRestore(success: false, error: "Das Backup ist nicht mit dieser App-Version kompatibel", tempDir: backupFolderURL, completion: completion)
            return
        }
        
        DispatchQueue.main.async {
            self.restoreProgress = 0.2
        }
        
        // Schritt 2: Core Data importieren
        let coreDataPath = backupFolderURL.appendingPathComponent("coredata_backup.sqlite")
        guard FileManager.default.fileExists(atPath: coreDataPath.path) else {
            finishRestore(success: false, error: "CoreData-Backup nicht gefunden", tempDir: backupFolderURL, completion: completion)
            return
        }
        
        coreDataCoordinator.importStore(from: coreDataPath) { [weak self] success, coreDataError in
            guard let self = self else { return }
            
            if !success {
                self.finishRestore(success: false, error: "CoreData-Import fehlgeschlagen: \(coreDataError ?? "Unbekannter Fehler")", tempDir: backupFolderURL, completion: completion)
                return
            }
            
            DispatchQueue.main.async {
                self.restoreProgress = 0.7
            }
            
            // Schritt 3: Belege importieren
            let receiptsDir = backupFolderURL.appendingPathComponent("receipts")
            guard FileManager.default.fileExists(atPath: receiptsDir.path) else {
                self.finishRestore(success: false, error: "Belege nicht gefunden", tempDir: backupFolderURL, completion: completion)
                return
            }
            
            receiptCoordinator.importReceipts(from: receiptsDir) { [weak self] success, receiptError in
                guard let self = self else { return }
                
                if !success {
                    self.finishRestore(success: false, error: "Belege-Import fehlgeschlagen: \(receiptError ?? "Unbekannter Fehler")", tempDir: backupFolderURL, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        self.restoreProgress = 1.0
                        self.isRestoreInProgress = false
                        completion(true, nil)
                    }
                }
            }
        }
    }
    
    /// Löscht ein Backup
    func deleteBackup(backupID: String, completion: @escaping (Bool, String?) -> Void) {
        guard let backupDir = backupDirectoryURL else {
            completion(false, "Backup-Verzeichnis nicht gefunden")
            return
        }
        
        let backupFolderURL = backupDir.appendingPathComponent(backupID)
        
        do {
            if FileManager.default.fileExists(atPath: backupFolderURL.path) {
                try FileManager.default.removeItem(at: backupFolderURL)
                
                // Nach dem Löschen die Liste aktualisieren
                loadAvailableBackups()
                
                completion(true, nil)
            } else {
                completion(false, "Backup nicht gefunden")
            }
        } catch {
            completion(false, "Fehler beim Löschen: \(error.localizedDescription)")
        }
    }
    
    /// Exportiert ein Backup zur Freigabe
    func exportBackup(backupID: String, completion: @escaping (URL?, String?) -> Void) {
        guard let backupDir = backupDirectoryURL else {
            completion(nil, "Backup-Verzeichnis nicht gefunden")
            return
        }
        
        // Backup-Verzeichnis
        let backupFolderURL = backupDir.appendingPathComponent(backupID)
        
        if !FileManager.default.fileExists(atPath: backupFolderURL.path) {
            completion(nil, "Backup nicht gefunden")
            return
        }
        
        // Temporäre ZIP-Datei für den Export erstellen
        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(backupID).zip")
        
        // Falls die temporäre Datei bereits existiert, löschen
        if FileManager.default.fileExists(atPath: tempZipURL.path) {
            try? FileManager.default.removeItem(at: tempZipURL)
        }
        
        do {
            // Wir erstellen ein sehr einfaches Archiv für den Export
            // Kopiere das gesamte Backup-Verzeichnis in einen temporären Bereich
            let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(backupID)_temp")
            
            // Falls das temporäre Verzeichnis existiert, löschen
            if FileManager.default.fileExists(atPath: tempDirURL.path) {
                try FileManager.default.removeItem(at: tempDirURL)
            }
            
            // Kopiere das Backup-Verzeichnis in den temporären Bereich
            try FileManager.default.copyItem(at: backupFolderURL, to: tempDirURL)
            
            // Erstelle eine .zip-Datei mit der SSZipArchive-Implementation
            if SSZipArchive.createZipFile(atPath: tempZipURL.path, withContentsOfDirectory: tempDirURL.path) {
                // Temporäres Verzeichnis aufräumen
                try FileManager.default.removeItem(at: tempDirURL)
                
                completion(tempZipURL, nil)
            } else {
                completion(nil, "Fehler beim Erstellen der ZIP-Datei")
            }
        } catch {
            completion(nil, "Fehler beim Exportieren: \(error.localizedDescription)")
        }
    }
    
    /// Importiert ein Backup aus einer gegebenen URL
    func importBackup(from url: URL, completion: @escaping (Bool, String?) -> Void) {
        guard let backupDir = backupDirectoryURL else {
            completion(false, "Backup-Verzeichnis nicht gefunden")
            return
        }
        
        // Prüfen, ob es eine ZIP-Datei ist
        if url.pathExtension.lowercased() != "zip" {
            completion(false, "Keine gültige Backup-Datei (ZIP erwartet)")
            return
        }
        
        // Temporäres Verzeichnis für die Extraktion
        let extractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            // Temporäres Verzeichnis erstellen
            try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
            
            // Extrahiere die ZIP-Datei mit SSZipArchive
            let extractSuccess = SSZipArchive.unzipFile(atPath: url.path, toDestination: extractDir.path)
            
            if !extractSuccess {
                try? FileManager.default.removeItem(at: extractDir)
                completion(false, "Fehler beim Entpacken der ZIP-Datei")
                return
            }
            
            // Logge den Inhalt des extrahierten Verzeichnisses
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: extractDir.path)
                ErrorLogger.shared.log(message: "Extrahierte Dateien: \(contents.joined(separator: ", "))")
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Auflisten der extrahierten Dateien")
            }
            
            // Prüfen, ob die erforderlichen Dateien vorhanden sind
            let versionPath = extractDir.appendingPathComponent("version.plist")
            let coreDataPath = extractDir.appendingPathComponent("coredata_backup.sqlite")
            
            guard FileManager.default.fileExists(atPath: versionPath.path) &&
                  FileManager.default.fileExists(atPath: coreDataPath.path) else {
                try? FileManager.default.removeItem(at: extractDir)
                completion(false, "Die ZIP-Datei enthält nicht alle erforderlichen Backup-Dateien")
                return
            }
            
            // Prüfen, ob die Version kompatibel ist
            do {
                let versionData = try Data(contentsOf: versionPath)
                if let versionInfo = try PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
                   let backupVersion = versionInfo["appVersion"] as? String,
                   !isBackupVersionCompatible(backupVersion) {
                    try? FileManager.default.removeItem(at: extractDir)
                    completion(false, "Das Backup ist nicht mit dieser App-Version kompatibel")
                    return
                }
            } catch {
                try? FileManager.default.removeItem(at: extractDir)
                completion(false, "Fehler beim Lesen der Versionsinformationen: \(error.localizedDescription)")
                return
            }
            
            // Erstelle ein neues Backup-Verzeichnis mit eindeutigem Namen
            let timestamp = Int(Date().timeIntervalSince1970)
            let backupID = "backup_\(timestamp)"
            let newBackupDir = backupDir.appendingPathComponent(backupID)
            
            // Kopiere den Inhalt des extrahierten Verzeichnisses in das neue Backup-Verzeichnis
            try FileManager.default.createDirectory(at: newBackupDir, withIntermediateDirectories: true)
            
            let extractedContents = try FileManager.default.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil)
            for item in extractedContents {
                let destPath = newBackupDir.appendingPathComponent(item.lastPathComponent)
                try FileManager.default.copyItem(at: item, to: destPath)
            }
            
            // Backup-Info-Datei erstellen oder aktualisieren
            let infoPath = newBackupDir.appendingPathComponent("backup.info")
            let infoContent = "timestamp: \(timestamp)\ndate: \(Date())\nimported: true\n"
            try infoContent.write(to: infoPath, atomically: true, encoding: .utf8)
            
            // Verzeichnis aufräumen
            try? FileManager.default.removeItem(at: extractDir)
            
            // Backup-Liste aktualisieren
            loadAvailableBackups()
            
            completion(true, nil)
        } catch {
            try? FileManager.default.removeItem(at: extractDir)
            completion(false, "Fehler beim Import des Backups: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Hilfsmethoden
    
    /// Beendet den Backup-Prozess und ruft den Completion-Handler auf
    private func finishBackup(success: Bool, error: String?, tempDir: URL, completion: @escaping (Bool, String?) -> Void) {
        // Versuche temporäres Verzeichnis aufzuräumen, falls ein Fehler auftritt
        if !success {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        DispatchQueue.main.async {
            self.isBackupInProgress = false
            self.backupProgress = success ? 1.0 : 0.0
            
            if success {
                self.lastBackupDate = Date()
                self.lastBackupStatus = .available
                self.loadAvailableBackups()
            } else {
                self.lastErrorMessage = error
                self.lastBackupStatus = .error
            }
            
            completion(success, error)
        }
    }
    
    /// Beendet den Wiederherstellungsprozess und ruft den Completion-Handler auf
    private func finishRestore(success: Bool, error: String?, tempDir: URL, completion: @escaping (Bool, String?) -> Void) {
        DispatchQueue.main.async {
            self.isRestoreInProgress = false
            self.restoreProgress = success ? 1.0 : 0.0
            
            if !success {
                self.lastErrorMessage = error
            }
            
            completion(success, error)
        }
    }
    
    /// Prüft, ob die Backup-Version mit der aktuellen App-Version kompatibel ist
    private func isBackupVersionCompatible(_ backupVersion: String) -> Bool {
        // In diesem Beispiel betrachten wir nur die Hauptversionsnummer
        // Format: 1.2.3 -> 1 ist die Hauptversion
        let currentMajorVersion = appVersion.split(separator: ".").first ?? ""
        let backupMajorVersion = backupVersion.split(separator: ".").first ?? ""
        
        return currentMajorVersion == backupMajorVersion
    }
    
    // MARK: - Automatische Backups
    
    /// Aktiviert tägliche automatische Backups
    func enableAutomaticBackups() {
        UserDefaults.standard.set(true, forKey: "automaticBackupsEnabled")
        scheduleNextAutomaticBackup()
    }
    
    /// Deaktiviert tägliche automatische Backups
    func disableAutomaticBackups() {
        UserDefaults.standard.set(false, forKey: "automaticBackupsEnabled")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["autoBackupReminder"])
    }
    
    /// Ist automatisches Backup aktiviert?
    var isAutomaticBackupEnabled: Bool {
        UserDefaults.standard.bool(forKey: "automaticBackupsEnabled")
    }
    
    /// Plant das nächste automatische Backup
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
