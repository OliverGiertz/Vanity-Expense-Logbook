import Foundation
import CoreData

/// Koordinator für das Backup und die Wiederherstellung von CoreData
class CoreDataBackupCoordinator: @unchecked Sendable {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Exportiert CoreData-Store in eine Datei
    func exportStore(to url: URL) async throws {
        try await context.perform { [self] in
            if context.hasChanges {
                try context.save()
            }
        }

        guard let coordinator = context.persistentStoreCoordinator else {
            throw CoordinatorError.noPersistentStoreCoordinator
        }
        guard let store = coordinator.persistentStores.first else {
            throw CoordinatorError.noStore
        }
        guard let originalURL = store.url else {
            throw CoordinatorError.noStoreURL
        }

        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let versionInfoURL = url.deletingLastPathComponent().appendingPathComponent("version.plist")
        let versionInfo: [String: Any] = [
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            "backupDate": Date()
        ]
        let versionData = try PropertyListSerialization.data(fromPropertyList: versionInfo, format: .xml, options: 0)
        try versionData.write(to: versionInfoURL)

        try FileManager.default.copyItem(at: originalURL, to: url)

        let shmURL = originalURL.appendingPathExtension("shm")
        let walURL = originalURL.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: shmURL.path) {
            try FileManager.default.copyItem(at: shmURL, to: url.appendingPathExtension("shm"))
        }
        if FileManager.default.fileExists(atPath: walURL.path) {
            try FileManager.default.copyItem(at: walURL, to: url.appendingPathExtension("wal"))
        }
    }

    /// Importiert CoreData-Store aus einer Datei
    func importStore(from url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CoordinatorError.backupFileNotFound
        }

        let container = PersistenceController.shared.container
        let coordinator = container.persistentStoreCoordinator

        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Entfernen des alten Stores")
                throw error
            }
        }

        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            throw CoordinatorError.noStoreURL
        }

        if FileManager.default.fileExists(atPath: storeURL.path) {
            try FileManager.default.removeItem(at: storeURL)
        }

        let shmURL = storeURL.appendingPathExtension("shm")
        let walURL = storeURL.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: shmURL.path) {
            try FileManager.default.removeItem(at: shmURL)
        }
        if FileManager.default.fileExists(atPath: walURL.path) {
            try FileManager.default.removeItem(at: walURL)
        }

        try FileManager.default.copyItem(at: url, to: storeURL)

        let backupShmURL = url.appendingPathExtension("shm")
        let backupWalURL = url.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: backupShmURL.path) {
            try FileManager.default.copyItem(at: backupShmURL, to: shmURL)
        }
        if FileManager.default.fileExists(atPath: backupWalURL.path) {
            try FileManager.default.copyItem(at: backupWalURL, to: walURL)
        }

        let options = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
        container.viewContext.reset()
    }

    enum CoordinatorError: LocalizedError {
        case noPersistentStoreCoordinator, noStore, noStoreURL, backupFileNotFound

        var errorDescription: String? {
            switch self {
            case .noPersistentStoreCoordinator: return "Kein PersistentStoreCoordinator verfügbar"
            case .noStore: return "Kein CoreData-Store gefunden"
            case .noStoreURL: return "Store-URL nicht verfügbar"
            case .backupFileNotFound: return "Backup-Datei nicht gefunden"
            }
        }
    }
}
