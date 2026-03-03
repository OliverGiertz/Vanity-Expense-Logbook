//
//  ReceiptBackupCoordinator.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 27.02.25.
//


import Foundation
import CoreData
import UIKit

/// Koordinator für das Backup und die Wiederherstellung von Beleg-Dokumenten.
/// Nutzt einen privaten Core-Data-Kontext, damit sämtliche Operationen thread-safe bleiben.
class ReceiptBackupCoordinator {
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
    
    /// Exportiert alle Belege in ein Verzeichnis
    func exportReceipts(to directoryURL: URL, completion: @escaping (Bool, Int, String?) -> Void) {
        workerContext.perform {
            let entryTypes = ["FuelEntry", "GasEntry", "ServiceEntry", "OtherEntry"]
            var totalReceiptCount = 0
            
            do {
                for entityName in entryTypes {
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
                    let entries = try self.workerContext.fetch(fetchRequest)
                    
                    for entry in entries {
                        if let receiptData = entry.value(forKey: "receiptData") as? Data {
                            let entryId = entry.value(forKey: "id") as? UUID ?? UUID()
                            var fileName = "\(entityName)_\(entryId.uuidString)"
                            
                            if let receiptType = entry.value(forKey: "receiptType") as? String {
                                fileName += receiptType == "pdf" ? ".pdf" : ".jpg"
                            } else if UIImage(data: receiptData) != nil {
                                fileName += ".jpg"
                            } else {
                                fileName += ".pdf"
                            }
                            
                            let fileURL = directoryURL.appendingPathComponent(fileName)
                            try receiptData.write(to: fileURL)
                            totalReceiptCount += 1
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(true, totalReceiptCount, nil)
                }
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Exportieren der Belege")
                DispatchQueue.main.async {
                    completion(false, totalReceiptCount, "Fehler beim Exportieren der Belege: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Importiert Belege aus einem Verzeichnis
    func importReceipts(from directoryURL: URL, completion: @escaping (Bool, String?) -> Void) {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            completion(false, "Beleg-Verzeichnis nicht gefunden")
            return
        }
        
        workerContext.perform {
            do {
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
                        try self.updateReceiptData(entityName: entityName, entryId: uuid, fileURL: fileURL)
                    }
                }
                
                if self.workerContext.hasChanges {
                    try self.workerContext.save()
                }
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Importieren der Belege")
                DispatchQueue.main.async {
                    completion(false, "Fehler beim Importieren der Belege: \(error.localizedDescription)")
                }
            }
        }
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
