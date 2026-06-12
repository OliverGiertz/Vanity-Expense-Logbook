import Foundation
import CoreData
import UIKit

/// Koordinator für das Backup und die Wiederherstellung von Beleg-Dokumenten.
/// Nutzt einen privaten Core-Data-Kontext, damit sämtliche Operationen thread-safe bleiben.
///
/// Thread-safety: Alle NSManagedObjectContext-Zugriffe erfolgen ausschließlich
/// über `workerContext.perform { }`, daher ist die `@unchecked Sendable`-Markierung korrekt.
class ReceiptBackupCoordinator: @unchecked Sendable {
    private let workerContext: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        if let coordinator = context.persistentStoreCoordinator {
            let privateContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            privateContext.persistentStoreCoordinator = coordinator
            privateContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            self.workerContext = privateContext
        } else {
            self.workerContext = context
        }
    }

    /// Exportiert alle Belege in ein Verzeichnis und gibt die Anzahl zurück
    func exportReceipts(to directoryURL: URL) async throws -> Int {
        try await workerContext.perform { [self] in
            let entryTypes = ["FuelEntry", "GasEntry", "ServiceEntry", "OtherEntry"]
            var totalReceiptCount = 0

            for entityName in entryTypes {
                let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                let entries = try workerContext.fetch(fetchRequest)

                for entry in entries {
                    if let receiptData = entry.value(forKey: "receiptData") as? Data {
                        let entryId = entry.value(forKey: "id") as? UUID ?? UUID()
                        var fileName = "\(entityName)_\(entryId.uuidString)"

                        fileName += Self.fileExtension(for: receiptData,
                                                             receiptType: entry.value(forKey: "receiptType") as? String)

                        let fileURL = directoryURL.appendingPathComponent(fileName)
                        try receiptData.write(to: fileURL)
                        totalReceiptCount += 1
                    }
                }
            }

            return totalReceiptCount
        }
    }

    /// Importiert Belege aus einem Verzeichnis
    func importReceipts(from directoryURL: URL) async throws {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            return // Kein Beleg-Verzeichnis ist kein Fehler (ältere Backups)
        }

        try await workerContext.perform { [self] in
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)

            for fileURL in fileURLs {
                let fileName = fileURL.lastPathComponent
                guard fileName.contains("_") else { continue }
                let parts = fileName.split(separator: "_", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let entityName = String(parts[0])
                var uuidString = String(parts[1])
                if uuidString.contains(".") {
                    uuidString = String(uuidString.split(separator: ".")[0])
                }

                if let uuid = UUID(uuidString: uuidString) {
                    try updateReceiptData(entityName: entityName, entryId: uuid, fileURL: fileURL)
                }
            }

            if workerContext.hasChanges {
                try workerContext.save()
            }
        }
    }

    /// Determines the file extension for receipt data from its stored type or file-header magic bytes.
    /// Avoids loading the full image into memory just to detect its type.
    private static func fileExtension(for data: Data, receiptType: String?) -> String {
        if let type = receiptType {
            return type == "pdf" ? ".pdf" : ".jpg"
        }
        // JPEG magic bytes: FF D8
        if data.prefix(2).elementsEqual([0xFF, 0xD8]) { return ".jpg" }
        // PDF magic bytes: %PDF (25 50 44 46)
        if data.prefix(4).elementsEqual([0x25, 0x50, 0x44, 0x46]) { return ".pdf" }
        return ".jpg"
    }

    /// Aktualisiert die Belegdaten eines Eintrags
    private func updateReceiptData(entityName: String, entryId: UUID, fileURL: URL) throws {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", entryId as CVarArg)
        fetchRequest.fetchLimit = 1

        let entries = try workerContext.fetch(fetchRequest)
        guard let entry = entries.first else { return }

        let fileExtension = fileURL.pathExtension.lowercased()
        let receiptData = try Data(contentsOf: fileURL)

        entry.setValue(receiptData, forKey: "receiptData")
        entry.setValue(fileExtension == "pdf" ? "pdf" : "image", forKey: "receiptType")
    }
}
