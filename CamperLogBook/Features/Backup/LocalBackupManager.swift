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
    
    // Backup-Verzeichnis im Documents-Verzeichnis – hier wird bewusst keine Exclusion gesetzt,
    // damit der Ordner auch für den User sichtbar ist (z. B. via Files-App).
    private var backupDirectoryURL: URL? {
        let fm = FileManager.default
        guard let documentDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let backupDir = documentDir.appendingPathComponent("\(appName) Backups")
        if !fm.fileExists(atPath: backupDir.path) {
            do {
                try fm.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)
                print("Backup-Verzeichnis erstellt: \(backupDir.path)")
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
        print("Backup-System mit CoreData verbunden.")
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
                // Es werden nur ZIP-Dateien berücksichtigt, die mit "backup_" beginnen.
                if item.lastPathComponent.hasPrefix("backup_") && item.pathExtension.lowercased() == "zip" {
                    let attrs = try FileManager.default.attributesOfItem(atPath: item.path)
                    let creationDate = attrs[.creationDate] as? Date ?? Date()
                    let backupID = item.deletingPathExtension().lastPathComponent
                    var version = appVersion
                    if let versionInfo = extractVersionFromZip(at: item) {
                        version = versionInfo
                    }
                    
                    backups.append(BackupInfo(
                        id: backupID,
                        date: creationDate,
                        version: version,
                        path: item
                    ))
                }
            }
            
            backups.sort { $0.date > $1.date }
            
            DispatchQueue.main.async {
                self.availableBackups = backups
                self.lastBackupStatus = backups.isEmpty ? .notAvailable : .available
                self.lastBackupDate = backups.first?.date
            }
            print("Verfügbare Backups neu geladen: \(backups.count) gefunden.")
        } catch {
            DispatchQueue.main.async {
                self.availableBackups = []
                self.lastBackupStatus = .error
                self.lastErrorMessage = "Fehler beim Laden der Backups: \(error.localizedDescription)"
            }
            print("Fehler beim Laden der Backups: \(error.localizedDescription)")
        }
    }
    
    /// Versucht, die Version aus einer ZIP-Datei zu extrahieren
    private func extractVersionFromZip(at zipURL: URL) -> String? {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: zipURL, to: tempDir)
            let versionPath = tempDir.appendingPathComponent("version.plist")
            if FileManager.default.fileExists(atPath: versionPath.path),
               let versionData = try? Data(contentsOf: versionPath),
               let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
               let backupVersion = versionInfo["appVersion"] as? String {
                print("Backup-Version extrahiert aus version.plist: \(backupVersion)")
                return backupVersion
            }
            // Fallback: Versuche die Version aus dem Manifest zu lesen
            let archiveData = try Data(contentsOf: zipURL)
            if let manifest = try ZipArchive.extractManifest(from: archiveData) {
                print("Backup-Version extrahiert aus Manifest: \(manifest.version)")
                return manifest.version
            }
            return nil
        } catch {
            print("Fehler beim Extrahieren der Backup-Version: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Backup-Operationen
    
    /// Erstellt ein Backup aller App-Daten:
    /// 1. Es wird ein temporäres Verzeichnis erstellt und mit CoreData- und Belegdaten befüllt.
    /// 2. Dieses Verzeichnis wird in das Backup-Verzeichnis kopiert.
    /// 3. Aus dem kopierten Ordner wird ein echtes ZIP-Archiv erstellt.
    /// 4. Nach erfolgreicher ZIP-Erstellung wird testweise nur das temporäre Verzeichnis gelöscht.
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
        
        DispatchQueue.main.async {
            self.isBackupInProgress = true
            self.backupProgress = 0.0
            self.lastErrorMessage = nil
            self.lastBackupStatus = .inProgress
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupID = "backup_\(timestamp)"
        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(backupID)
        
        do {
            // Temporäres Verzeichnis erstellen
            if FileManager.default.fileExists(atPath: tempDirURL.path) {
                try FileManager.default.removeItem(at: tempDirURL)
            }
            try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
            print("Temporäres Verzeichnis erstellt: \(tempDirURL.path)")
            
            // Schritt 1: CoreData exportieren
            let coreDataURL = tempDirURL.appendingPathComponent("coredata_backup.sqlite")
            print("Starte CoreData-Export nach: \(coreDataURL.path)")
            coreDataCoordinator.exportStore(to: coreDataURL) { [weak self] success, error in
                guard let self = self else { return }
                if !success {
                    print("CoreData-Export fehlgeschlagen: \(error ?? "Unbekannter Fehler")")
                    self.finishBackup(success: false, error: error, tempDir: tempDirURL, completion: completion)
                    return
                }
                print("CoreData-Export erfolgreich.")
                DispatchQueue.main.async { self.backupProgress = 0.3 }
                
                // Schritt 2: Belege exportieren
                let receiptsURL = tempDirURL.appendingPathComponent("receipts")
                try? FileManager.default.createDirectory(at: receiptsURL, withIntermediateDirectories: true)
                print("Starte Belege-Export nach: \(receiptsURL.path)")
                receiptCoordinator.exportReceipts(to: receiptsURL) { [weak self] success, receiptCount, error in
                    guard let self = self else { return }
                    if !success {
                        print("Belege-Export fehlgeschlagen: \(error ?? "Unbekannter Fehler")")
                        self.finishBackup(success: false, error: error, tempDir: tempDirURL, completion: completion)
                        return
                    }
                    print("Belege-Export erfolgreich. Anzahl Belege: \(receiptCount)")
                    DispatchQueue.main.async { self.backupProgress = 0.6 }
                    
                    // Schritt 3: Versionsinfo erstellen
                    let versionInfoPath = tempDirURL.appendingPathComponent("version.plist")
                    let versionInfo: [String: Any] = [
                        "appVersion": self.appVersion,
                        "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                        "backupDate": Date(),
                        "receiptCount": receiptCount
                    ]
                    
                    do {
                        let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
                        try versionData.write(to: versionInfoPath)
                        print("Versionsinfo erstellt unter: \(versionInfoPath.path)")
                        
                        // Backup-Info-Datei erstellen
                        let infoPath = tempDirURL.appendingPathComponent("backup.info")
                        let infoContent = "timestamp: \(timestamp)\ndate: \(Date())\n"
                        try infoContent.write(to: infoPath, atomically: true, encoding: .utf8)
                        print("Backup-Info-Datei erstellt: \(infoPath.path)")
                        
                        // Schritt 4: Kopiere das temporäre Verzeichnis in das Backup-Verzeichnis
                        let backupFolderURL = backupDir.appendingPathComponent(backupID)
                        try FileManager.default.copyItem(at: tempDirURL, to: backupFolderURL)
                        print("Temporäres Verzeichnis kopiert nach: \(backupFolderURL.path)")
                        
                        // Schritt 5: Erstelle ein ZIP-Archiv aus dem kopierten Ordner
                        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
                        print("Erstelle ZIP-Archiv unter: \(zipURL.path)")
                        try FileManager.default.zipItem(at: backupFolderURL, to: zipURL)
                        print("ZIP-Archiv erfolgreich erstellt.")
                        
                        // Schritt 6: Lösche testweise nur das temporäre Verzeichnis, das kopierte Verzeichnis bleibt bestehen
                        try FileManager.default.removeItem(at: tempDirURL)
                        print("Temporäres Verzeichnis gelöscht: \(tempDirURL.path)")
                        
                        DispatchQueue.main.async {
                            self.backupProgress = 1.0
                            self.lastBackupDate = Date()
                            self.lastBackupStatus = .available
                            self.loadAvailableBackups()
                            completion(true, nil)
                        }
                    } catch {
                        print("Fehler beim Erstellen der Versionsdatei oder beim Kopieren: \(error.localizedDescription)")
                        self.finishBackup(success: false, error: "Fehler beim Erstellen der Versionsdatei: \(error.localizedDescription)", tempDir: tempDirURL, completion: completion)
                    }
                }
            }
        } catch {
            print("Fehler bei der Backup-Vorbereitung: \(error.localizedDescription)")
            finishBackup(success: false, error: "Fehler bei der Backup-Vorbereitung: \(error.localizedDescription)", tempDir: tempDirURL, completion: completion)
        }
    }
    
    /// Stellt ein Backup wieder her (ZIP entpacken, Version prüfen, CoreData und Belege importieren)
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
        
        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        if !FileManager.default.fileExists(atPath: zipURL.path) {
            completion(false, "Backup nicht gefunden")
            return
        }
        
        DispatchQueue.main.async {
            self.isRestoreInProgress = true
            self.restoreProgress = 0.0
            self.lastErrorMessage = nil
        }
        
        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("restore_\(backupID)")
        if FileManager.default.fileExists(atPath: tempDirURL.path) {
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        
        do {
            try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
            print("Restore: Temporäres Verzeichnis erstellt: \(tempDirURL.path)")
            try FileManager.default.unzipItem(at: zipURL, to: tempDirURL)
            print("Restore: ZIP-Archiv entpackt von: \(zipURL.path)")
            
            // Debug: Zeige den Inhalt des entpackten Ordners
            let contents = try FileManager.default.contentsOfDirectory(at: tempDirURL, includingPropertiesForKeys: nil)
            print("Restore: Inhalt des entpackten Ordners: \(contents.map { $0.lastPathComponent })")
            
            DispatchQueue.main.async { self.restoreProgress = 0.2 }
            
            // Versuche zuerst, die Version aus der version.plist zu lesen
            let versionPath = tempDirURL.appendingPathComponent("version.plist")
            var backupVersion: String?
            if FileManager.default.fileExists(atPath: versionPath.path),
               let versionData = try? Data(contentsOf: versionPath),
               let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
               let v = versionInfo["appVersion"] as? String {
                backupVersion = v
                print("Restore: Backup-Version aus version.plist: \(v)")
            } else {
                // Fallback: Versuche die Version aus dem Manifest zu lesen
                let archiveData = try Data(contentsOf: zipURL)
                if let manifest = try ZipArchive.extractManifest(from: archiveData) {
                    backupVersion = manifest.version
                    print("Restore: Backup-Version aus Manifest: \(manifest.version)")
                }
            }
            
            guard let backupVersionFinal = backupVersion else {
                finishRestore(success: false, error: "Ungültiges Backup-Format oder fehlende Versionsinformationen", tempDir: tempDirURL, completion: completion)
                return
            }
            
            let isCompatible = isBackupVersionCompatible(backupVersionFinal)
            guard isCompatible else {
                finishRestore(success: false, error: "Das Backup ist nicht mit dieser App-Version kompatibel", tempDir: tempDirURL, completion: completion)
                return
            }
            
            let coreDataPath = tempDirURL.appendingPathComponent("coredata_backup.sqlite")
            guard FileManager.default.fileExists(atPath: coreDataPath.path) else {
                finishRestore(success: false, error: "CoreData-Backup nicht gefunden", tempDir: tempDirURL, completion: completion)
                return
            }
            print("Restore: CoreData-Backup gefunden: \(coreDataPath.path)")
            
            coreDataCoordinator.importStore(from: coreDataPath) { [weak self] success, coreDataError in
                guard let self = self else { return }
                if !success {
                    print("Restore: CoreData-Import fehlgeschlagen: \(coreDataError ?? "Unbekannter Fehler")")
                    self.finishRestore(success: false, error: "CoreData-Import fehlgeschlagen: \(coreDataError ?? "Unbekannter Fehler")", tempDir: tempDirURL, completion: completion)
                    return
                }
                print("Restore: CoreData-Import erfolgreich.")
                DispatchQueue.main.async { self.restoreProgress = 0.7 }
                
                let receiptsDir = tempDirURL.appendingPathComponent("receipts")
                guard FileManager.default.fileExists(atPath: receiptsDir.path) else {
                    self.finishRestore(success: false, error: "Belege nicht gefunden", tempDir: tempDirURL, completion: completion)
                    return
                }
                print("Restore: Belege-Verzeichnis gefunden: \(receiptsDir.path)")
                
                receiptCoordinator.importReceipts(from: receiptsDir) { [weak self] success, receiptError in
                    guard let self = self else { return }
                    if !success {
                        print("Restore: Belege-Import fehlgeschlagen: \(receiptError ?? "Unbekannter Fehler")")
                        self.finishRestore(success: false, error: "Belege-Import fehlgeschlagen: \(receiptError ?? "Unbekannter Fehler")", tempDir: tempDirURL, completion: completion)
                    } else {
                        try? FileManager.default.removeItem(at: tempDirURL)
                        print("Restore: Temporäres Verzeichnis gelöscht: \(tempDirURL.path)")
                        DispatchQueue.main.async {
                            self.restoreProgress = 1.0
                            self.isRestoreInProgress = false
                            completion(true, nil)
                        }
                    }
                }
            }
        } catch {
            print("Restore: Fehler beim Entpacken des Backups: \(error.localizedDescription)")
            finishRestore(success: false, error: "Fehler beim Entpacken des Backups: \(error.localizedDescription)", tempDir: tempDirURL, completion: completion)
        }
    }
    
    /// Importiert ein Backup von einem vom User ausgewählten ZIP
    func importBackup(from zipURL: URL, completion: @escaping (Bool, String?) -> Void) {
        guard FileManager.default.fileExists(atPath: zipURL.path) else {
            completion(false, "Backup nicht gefunden")
            return
        }
        
        DispatchQueue.main.async {
            self.isRestoreInProgress = true
            self.restoreProgress = 0.0
            self.lastErrorMessage = nil
        }
        
        let tempDirURL = FileManager.default.temporaryDirectory.appendingPathComponent("import_\(Int(Date().timeIntervalSince1970))")
        if FileManager.default.fileExists(atPath: tempDirURL.path) {
            try? FileManager.default.removeItem(at: tempDirURL)
        }
        
        do {
            try FileManager.default.createDirectory(at: tempDirURL, withIntermediateDirectories: true)
            print("Import: Temporäres Verzeichnis erstellt: \(tempDirURL.path)")
            try FileManager.default.unzipItem(at: zipURL, to: tempDirURL)
            print("Import: ZIP-Archiv entpackt von: \(zipURL.path)")
            DispatchQueue.main.async { self.restoreProgress = 0.2 }
            
            let versionPath = tempDirURL.appendingPathComponent("version.plist")
            var backupVersion: String?
            if FileManager.default.fileExists(atPath: versionPath.path),
               let versionData = try? Data(contentsOf: versionPath),
               let versionInfo = try? PropertyListSerialization.propertyList(from: versionData, format: nil) as? [String: Any],
               let v = versionInfo["appVersion"] as? String {
                backupVersion = v
                print("Import: Backup-Version aus version.plist: \(v)")
            } else {
                let archiveData = try Data(contentsOf: zipURL)
                if let manifest = try ZipArchive.extractManifest(from: archiveData) {
                    backupVersion = manifest.version
                    print("Import: Backup-Version aus Manifest: \(manifest.version)")
                }
            }
            
            guard let backupVersionFinal = backupVersion else {
                finishRestore(success: false, error: "Ungültiges Backup-Format oder fehlende Versionsinformationen", tempDir: tempDirURL, completion: completion)
                return
            }
            
            let isCompatible = isBackupVersionCompatible(backupVersionFinal)
            guard isCompatible else {
                finishRestore(success: false, error: "Das Backup ist nicht mit dieser App-Version kompatibel", tempDir: tempDirURL, completion: completion)
                return
            }
            
            let coreDataPath = tempDirURL.appendingPathComponent("coredata_backup.sqlite")
            guard FileManager.default.fileExists(atPath: coreDataPath.path) else {
                finishRestore(success: false, error: "CoreData-Backup nicht gefunden", tempDir: tempDirURL, completion: completion)
                return
            }
            print("Import: CoreData-Backup gefunden: \(coreDataPath.path)")
            
            coreDataCoordinator?.importStore(from: coreDataPath) { [weak self] success, coreDataError in
                guard let self = self else { return }
                if !success {
                    print("Import: CoreData-Import fehlgeschlagen: \(coreDataError ?? "Unbekannter Fehler")")
                    self.finishRestore(success: false, error: "CoreData-Import fehlgeschlagen: \(coreDataError ?? "Unbekannter Fehler")", tempDir: tempDirURL, completion: completion)
                    return
                }
                print("Import: CoreData-Import erfolgreich.")
                DispatchQueue.main.async { self.restoreProgress = 0.7 }
                
                let receiptsDir = tempDirURL.appendingPathComponent("receipts")
                guard FileManager.default.fileExists(atPath: receiptsDir.path) else {
                    self.finishRestore(success: false, error: "Belege nicht gefunden", tempDir: tempDirURL, completion: completion)
                    return
                }
                print("Import: Belege-Verzeichnis gefunden: \(receiptsDir.path)")
                
                self.receiptCoordinator?.importReceipts(from: receiptsDir) { [weak self] success, receiptError in
                    guard let self = self else { return }
                    if !success {
                        print("Import: Belege-Import fehlgeschlagen: \(receiptError ?? "Unbekannter Fehler")")
                        self.finishRestore(success: false, error: "Belege-Import fehlgeschlagen: \(receiptError ?? "Unbekannter Fehler")", tempDir: tempDirURL, completion: completion)
                    } else {
                        try? FileManager.default.removeItem(at: tempDirURL)
                        print("Import: Temporäres Verzeichnis gelöscht: \(tempDirURL.path)")
                        DispatchQueue.main.async {
                            self.restoreProgress = 1.0
                            self.isRestoreInProgress = false
                            completion(true, nil)
                        }
                    }
                }
            }
        } catch {
            print("Import: Fehler beim Entpacken des Backups: \(error.localizedDescription)")
            finishRestore(success: false, error: "Fehler beim Entpacken des Backups: \(error.localizedDescription)", tempDir: tempDirURL, completion: completion)
        }
    }
    
    /// Löscht ein Backup
    func deleteBackup(backupID: String, completion: @escaping (Bool, String?) -> Void) {
        guard let backupDir = backupDirectoryURL else {
            completion(false, "Backup-Verzeichnis nicht gefunden")
            return
        }
        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        do {
            if FileManager.default.fileExists(atPath: zipURL.path) {
                try FileManager.default.removeItem(at: zipURL)
                print("Backup gelöscht: \(zipURL.path)")
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
        let zipURL = backupDir.appendingPathComponent("\(backupID).zip")
        if !FileManager.default.fileExists(atPath: zipURL.path) {
            completion(nil, "Backup nicht gefunden")
            return
        }
        let tempZipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(backupID).zip")
        if FileManager.default.fileExists(atPath: tempZipURL.path) {
            try? FileManager.default.removeItem(at: tempZipURL)
        }
        do {
            try FileManager.default.copyItem(at: zipURL, to: tempZipURL)
            print("Backup exportiert nach: \(tempZipURL.path)")
            completion(tempZipURL, nil)
        } catch {
            completion(nil, "Fehler beim Exportieren: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Hilfsmethoden
    
    private func finishBackup(success: Bool, error: String?, tempDir: URL, completion: @escaping (Bool, String?) -> Void) {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
            print("FinishBackup: Temporäres Verzeichnis entfernt: \(tempDir.path)")
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
    
    private func finishRestore(success: Bool, error: String?, tempDir: URL, completion: @escaping (Bool, String?) -> Void) {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.removeItem(at: tempDir)
            print("FinishRestore: Temporäres Verzeichnis entfernt: \(tempDir.path)")
        }
        DispatchQueue.main.async {
            self.isRestoreInProgress = false
            self.restoreProgress = success ? 1.0 : 0.0
            if !success {
                self.lastErrorMessage = error
            }
            completion(success, error)
        }
    }
    
    private func isBackupVersionCompatible(_ backupVersion: String) -> Bool {
        let currentMajorVersion = appVersion.split(separator: ".").first ?? ""
        let backupMajorVersion = backupVersion.split(separator: ".").first ?? ""
        return currentMajorVersion == backupMajorVersion
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
