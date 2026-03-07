import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CamperLogBook")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Enable lightweight migration by default.
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            // Keep loading deterministic in app startup paths.
            description.shouldAddStoreAsynchronously = false
        }

        var loadError: NSError?
        container.loadPersistentStores { _, error in
            if let nsError = error as NSError? {
                loadError = nsError
            }
        }

        // If migration fails due to missing mapping model, back up and reset the store to avoid app crash loop.
        if let error = loadError,
           !inMemory,
           Self.isMissingMappingModelMigrationError(error),
           let storeURL = description.url {
            NSLog("CoreData migration failed with missing mapping model. Backing up and resetting store. Error: \(error)")

            do {
                try Self.backupStoreFiles(at: storeURL)
                try Self.removeStoreFiles(at: storeURL)

                loadError = nil
                container.loadPersistentStores { _, error in
                    if let nsError = error as NSError? {
                        loadError = nsError
                    }
                }
            } catch {
                fatalError("Failed to recover persistent store after migration error: \(error)")
            }
        }

        if let error = loadError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func isMissingMappingModelMigrationError(_ error: NSError) -> Bool {
        // NSMigrationMissingMappingModelError
        let isMigrationError = error.domain == NSCocoaErrorDomain && error.code == 134140
        let message = error.localizedDescription.lowercased()
        return isMigrationError || message.contains("missing mapping model")
    }

    private static func backupStoreFiles(at storeURL: URL) throws {
        let fm = FileManager.default
        let backupDir = storeURL.deletingLastPathComponent().appendingPathComponent("MigrationRecoveryBackup", isDirectory: true)
        if !fm.fileExists(atPath: backupDir.path) {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }

        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let files = [storeURL, storeURL.appendingPathExtension("shm"), storeURL.appendingPathExtension("wal")]

        for file in files where fm.fileExists(atPath: file.path) {
            let target = backupDir.appendingPathComponent("\(file.lastPathComponent).\(stamp).bak")
            try fm.copyItem(at: file, to: target)
        }
    }

    private static func removeStoreFiles(at storeURL: URL) throws {
        let fm = FileManager.default
        let files = [storeURL, storeURL.appendingPathExtension("shm"), storeURL.appendingPathExtension("wal")]
        for file in files where fm.fileExists(atPath: file.path) {
            try fm.removeItem(at: file)
        }
    }
}
