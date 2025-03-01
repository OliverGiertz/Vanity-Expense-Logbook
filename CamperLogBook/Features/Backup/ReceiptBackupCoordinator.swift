//
//  ReceiptBackupCoordinator.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 27.02.25.
//


import Foundation
import CoreData
import UIKit

/// Koordinator für das Backup und die Wiederherstellung von Beleg-Dokumenten
class ReceiptBackupCoordinator {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Exportiert alle Belege in ein Verzeichnis
    func exportReceipts(to directoryURL: URL, completion: @escaping (Bool, Int, String?) -> Void) {
        let entryTypes = ["FuelEntry", "GasEntry", "ServiceEntry", "OtherEntry"]
        var totalReceiptCount = 0
        
        for entityName in entryTypes {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            
            do {
                let entries = try context.fetch(fetchRequest)
                
                for entry in entries {
                    if let receiptData = entry.value(forKey: "receiptData") as? Data {
                        let entryId = entry.value(forKey: "id") as? UUID ?? UUID()
                        var fileName = "\(entityName)_\(entryId.uuidString)"
                        
                        // Bestimme Dateityp
                        if let receiptType = entry.value(forKey: "receiptType") as? String {
                            if receiptType == "pdf" {
                                fileName += ".pdf"
                            } else {
                                fileName += ".jpg"
                            }
                        } else {
                            // Fallback, wenn kein Typ angegeben ist
                            if UIImage(data: receiptData) != nil {
                                fileName += ".jpg"
                            } else {
                                fileName += ".pdf"
                            }
                        }
                        
                        let fileURL = directoryURL.appendingPathComponent(fileName)
                        try receiptData.write(to: fileURL)
                        totalReceiptCount += 1
                    }
                }
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Exportieren der Belege für \(entityName)")
                completion(false, totalReceiptCount, "Fehler beim Exportieren der Belege: \(error.localizedDescription)")
                return
            }
        }
        
        completion(true, totalReceiptCount, nil)
    }
    
    /// Importiert Belege aus einem Verzeichnis
    func importReceipts(from directoryURL: URL, completion: @escaping (Bool, String?) -> Void) {
        guard FileManager.default.fileExists(atPath: directoryURL.path) else {
            completion(false, "Beleg-Verzeichnis nicht gefunden")
            return
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                let fileName = fileURL.lastPathComponent
                
                // Prüfe, ob Dateiname dem Format entspricht
                if fileName.contains("_") {
                    let parts = fileName.split(separator: "_", maxSplits: 1)
                    if parts.count == 2 {
                        let entityName = String(parts[0])
                        var uuidString = String(parts[1])
                        
                        // Entferne Dateiendung
                        if uuidString.contains(".") {
                            uuidString = String(uuidString.split(separator: ".")[0])
                        }
                        
                        if let uuid = UUID(uuidString: uuidString) {
                            // Suche Entry mit dieser UUID
                            updateReceiptData(entityName: entityName, entryId: uuid, fileURL: fileURL)
                        }
                    }
                }
            }
            
            completion(true, nil)
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Importieren der Belege")
            completion(false, "Fehler beim Importieren der Belege: \(error.localizedDescription)")
        }
    }
    
    /// Aktualisiert die Belegdaten eines Eintrags
    private func updateReceiptData(entityName: String, entryId: UUID, fileURL: URL) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
        fetchRequest.predicate = NSPredicate(format: "id == %@", entryId as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let entries = try context.fetch(fetchRequest)
            
            if let entry = entries.first {
                let fileExtension = fileURL.pathExtension.lowercased()
                let receiptData = try Data(contentsOf: fileURL)
                
                entry.setValue(receiptData, forKey: "receiptData")
                
                // Setze den Typ basierend auf der Dateiendung
                if fileExtension == "pdf" {
                    entry.setValue("pdf", forKey: "receiptType")
                } else {
                    entry.setValue("image", forKey: "receiptType")
                }
                
                try context.save()
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Aktualisieren der Belegdaten für \(entityName), ID: \(entryId)")
        }
    }
}