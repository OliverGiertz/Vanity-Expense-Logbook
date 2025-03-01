import Foundation
import CoreData

/// Koordinator für das Backup und die Wiederherstellung von CoreData
class CoreDataBackupCoordinator {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Exportiert CoreData-Store in eine Datei
    func exportStore(to url: URL, completion: @escaping (Bool, String?) -> Void) {
        // Ensure that the CoreData context is saved first
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Speichern des Kontexts vor dem Export")
            completion(false, "Fehler beim Vorbereiten der Datenbank: \(error.localizedDescription)")
            return
        }
        
        let coordinator = context.persistentStoreCoordinator!
        guard let store = coordinator.persistentStores.first else {
            completion(false, "Kein CoreData-Store gefunden")
            return
        }
        
        // Stelle sicher, dass das Verzeichnis für die URL existiert
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Erstellen des Verzeichnisses für CoreData-Export")
            completion(false, "Fehler beim Erstellen des Verzeichnisses: \(error.localizedDescription)")
            return
        }
        
        // Statt zu migrieren, erstellen wir eine Kopie des Stores
        let originalURL = store.url!
        
        do {
            // Erzeuge eine Version-Info Datei
            let versionInfoURL = url.deletingLastPathComponent().appendingPathComponent("version.plist")
            let versionInfo: [String: Any] = [
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
                "backupDate": Date()
            ]
            
            let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
            try versionData.write(to: versionInfoURL)
            
            // Kopiere die Datenbankdatei direkt
            try FileManager.default.copyItem(at: originalURL, to: url)
            
            // Kopiere auch die -shm und -wal Dateien, falls vorhanden
            let shmURL = originalURL.appendingPathExtension("shm")
            let walURL = originalURL.appendingPathExtension("wal")
            
            if FileManager.default.fileExists(atPath: shmURL.path) {
                try FileManager.default.copyItem(at: shmURL, to: url.appendingPathExtension("shm"))
            }
            
            if FileManager.default.fileExists(atPath: walURL.path) {
                try FileManager.default.copyItem(at: walURL, to: url.appendingPathExtension("wal"))
            }
            
            completion(true, nil)
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "CoreData-Export fehlgeschlagen")
            completion(false, error.localizedDescription)
        }
    }
    
    /// Importiert CoreData-Store aus einer Datei
    func importStore(from url: URL, completion: @escaping (Bool, String?) -> Void) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(false, "Backup-Datei nicht gefunden")
            return
        }
        
        let container = PersistenceController.shared.container
        let coordinator = container.persistentStoreCoordinator
        
        // Erstelle einen temporären Kontext für die Importoperation
        let tempContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        tempContext.persistentStoreCoordinator = coordinator
        
        // Schließe aktuelle Stores
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Entfernen des alten Stores")
                completion(false, "Fehler beim Vorbereiten der Datenbank: \(error.localizedDescription)")
                return
            }
        }
        
        do {
            // Lösche aktuelle Datenbankdatei
            if let storeURL = container.persistentStoreDescriptions.first?.url {
                if FileManager.default.fileExists(atPath: storeURL.path) {
                    try FileManager.default.removeItem(at: storeURL)
                }
                
                // Lösche auch die -shm und -wal Dateien, falls vorhanden
                let shmURL = storeURL.appendingPathExtension("shm")
                let walURL = storeURL.appendingPathExtension("wal")
                
                if FileManager.default.fileExists(atPath: shmURL.path) {
                    try FileManager.default.removeItem(at: shmURL)
                }
                
                if FileManager.default.fileExists(atPath: walURL.path) {
                    try FileManager.default.removeItem(at: walURL)
                }
                
                // Kopiere die Backup-Datei an die richtige Stelle
                try FileManager.default.copyItem(at: url, to: storeURL)
                
                // Kopiere auch die -shm und -wal Dateien, falls vorhanden
                let backupShmURL = url.appendingPathExtension("shm")
                let backupWalURL = url.appendingPathExtension("wal")
                
                if FileManager.default.fileExists(atPath: backupShmURL.path) {
                    try FileManager.default.copyItem(at: backupShmURL, to: shmURL)
                }
                
                if FileManager.default.fileExists(atPath: backupWalURL.path) {
                    try FileManager.default.copyItem(at: backupWalURL, to: walURL)
                }
                
                // Füge den Store wieder hinzu
                let options = [
                    NSMigratePersistentStoresAutomaticallyOption: true,
                    NSInferMappingModelAutomaticallyOption: true
                ]
                
                try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
                
                // Setze den Kontext zurück
                container.viewContext.reset()
                
                completion(true, nil)
            } else {
                completion(false, "Keine gültige Store-URL gefunden")
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "CoreData-Import fehlgeschlagen")
            completion(false, error.localizedDescription)
        }
    }
}
