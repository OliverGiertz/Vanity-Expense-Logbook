import Foundation
import CoreData

enum CSVHelperEntryType {
    case fuel
    case gas
    case other
}

struct CSVHelper {
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter
    }()
    
    /// Hilfsfunktion, die einen String normalisiert, indem alle Kommas durch Punkte ersetzt werden,
    /// und anschließend versucht, einen Double-Wert zu erzeugen.
    private static func parseDouble(from string: String) -> Double? {
        let normalized = string.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(normalized)
    }
    
    /// Importiert eine CSV-Datei (Semikolon-getrennt) und erstellt Core Data-Objekte.
    /// - Parameters:
    ///   - type: Der zu importierende Eintragstyp.
    ///   - url: Die URL der CSV-Datei.
    ///   - context: Der NSManagedObjectContext.
    /// - Returns: Anzahl der importierten Einträge.
    static func importCSV(for type: CSVHelperEntryType, from url: URL, in context: NSManagedObjectContext) throws -> Int {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return 0 }
        let headers = headerLine.components(separatedBy: ";")
        var importedCount = 0
        
        for line in lines.dropFirst() {
            let values = line.components(separatedBy: ";")
            if values.count < headers.count { continue }
            var row = [String: String]()
            for (index, header) in headers.enumerated() {
                row[header] = values[index]
            }
            // Alle Keys in Kleinbuchstaben umwandeln
            let rowLower = Dictionary(uniqueKeysWithValues: row.map { (key, value) in (key.lowercased(), value) } )
            switch type {
            case .fuel:
                if let _ = try? importFuelEntry(from: rowLower, in: context) {
                    importedCount += 1
                }
            case .gas:
                if let _ = try? importGasEntry(from: rowLower, in: context) {
                    importedCount += 1
                }
            case .other:
                if let _ = try? importOtherEntry(from: rowLower, in: context) {
                    importedCount += 1
                }
            }
        }
        if context.hasChanges {
            try context.save()
        }
        return importedCount
    }
    
    private static func importFuelEntry(from row: [String: String], in context: NSManagedObjectContext) throws -> FuelEntry? {
        // Erwarteter Header: date;isdiesel;isadblue;currentkm;liters;costperliter;totalcost;latitude;longitude;receiptdata
        guard let dateString = row["date"], let date = dateFormatter.date(from: dateString) else { return nil }
        let entry = FuelEntry(context: context)
        entry.id = UUID()
        entry.date = date
        
        if let isDieselStr = row["isdiesel"] {
            entry.isDiesel = (isDieselStr.trimmingCharacters(in: .whitespaces) == "1")
        }
        if let isAdBlueStr = row["isadblue"] {
            entry.isAdBlue = (isAdBlueStr.trimmingCharacters(in: .whitespaces) == "1")
        }
        if let currentKmStr = row["currentkm"] {
            let kmString = currentKmStr.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
            if let km = Int64(kmString) {
                entry.currentKm = km
            }
        }
        if let litersStr = row["liters"], let liters = parseDouble(from: litersStr) {
            entry.liters = liters
        }
        if let costPerLiterStr = row["costperliter"] {
            let costStr = costPerLiterStr
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
            if let cost = parseDouble(from: costStr) {
                entry.costPerLiter = cost
            }
        }
        if let totalCostStr = row["totalcost"] {
            let totalStr = totalCostStr
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
            if let total = parseDouble(from: totalStr) {
                entry.totalCost = total
            }
        }
        // GPS-Werte: zuerst "latitude" bzw. "longitude", falls nicht vorhanden "lat"/"lon"
        let latKey = row["latitude"] ?? row["lat"] ?? ""
        if !latKey.isEmpty, let lat = parseDouble(from: latKey) {
            entry.latitude = lat
        }
        let lonKey = row["longitude"] ?? row["lon"] ?? ""
        if !lonKey.isEmpty, let lon = parseDouble(from: lonKey) {
            entry.longitude = lon
        }
        if let receiptDataStr = row["receiptdata"], !receiptDataStr.isEmpty,
           let data = Data(base64Encoded: receiptDataStr) {
            entry.receiptData = data
        }
        return entry
    }
    
    private static func importGasEntry(from row: [String: String], in context: NSManagedObjectContext) throws -> GasEntry? {
        guard let dateString = row["date"], let date = dateFormatter.date(from: dateString) else { return nil }
        let entry = GasEntry(context: context)
        entry.id = UUID()
        entry.date = date
        if let costPerBottleStr = row["costperbottle"] {
            let costStr = costPerBottleStr
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
            if let costPerBottle = parseDouble(from: costStr) {
                entry.costPerBottle = costPerBottle
            }
        }
        if let bottleCountStr = row["bottlecount"]?.trimmingCharacters(in: .whitespaces),
           let count = Int64(bottleCountStr) {
            entry.bottleCount = count
        }
        let latKey = row["latitude"] ?? row["lat"] ?? ""
        if !latKey.isEmpty, let lat = parseDouble(from: latKey) {
            entry.latitude = lat
        }
        let lonKey = row["longitude"] ?? row["lon"] ?? ""
        if !lonKey.isEmpty, let lon = parseDouble(from: lonKey) {
            entry.longitude = lon
        }
        if let receiptDataStr = row["receiptdata"], !receiptDataStr.isEmpty,
           let data = Data(base64Encoded: receiptDataStr) {
            entry.receiptData = data
        }
        return entry
    }
    
    private static func importOtherEntry(from row: [String: String], in context: NSManagedObjectContext) throws -> OtherEntry? {
        guard let dateString = row["date"], let date = dateFormatter.date(from: dateString) else { return nil }
        let entry = OtherEntry(context: context)
        entry.id = UUID()
        entry.date = date
        if let category = row["category"], !category.isEmpty {
            entry.category = category
        }
        if let details = row["details"] {
            entry.details = details
        }
        if let costStr = row["cost"] {
            let costClean = costStr
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
            if let cost = parseDouble(from: costClean) {
                entry.cost = cost
            }
        }
        let latKey = row["latitude"] ?? row["lat"] ?? ""
        if !latKey.isEmpty, let lat = parseDouble(from: latKey) {
            entry.latitude = lat
        }
        let lonKey = row["longitude"] ?? row["lon"] ?? ""
        if !lonKey.isEmpty, let lon = parseDouble(from: lonKey) {
            entry.longitude = lon
        }
        if let receiptDataStr = row["receiptdata"], !receiptDataStr.isEmpty,
           let data = Data(base64Encoded: receiptDataStr) {
            entry.receiptData = data
        }
        return entry
    }
    
    /// Erzeugt eine CSV-Datei (als String) mit einheitlichen Spalten für alle ausgewählten Typen.
    /// (Export erfolgt weiterhin tab-getrennt.)
    static func generateCSV(forTypes types: [CSVHelperEntryType], in context: NSManagedObjectContext) -> String {
        let header = ["entryType", "date", "isDiesel", "isAdBlue", "currentKm", "liters", "costPerLiter", "totalCost", "costPerBottle", "bottleCount", "category", "details", "cost", "latitude", "longitude", "receiptData"]
        var rows = [header.joined(separator: "\t")]
        
        func encodeReceiptData(_ data: Data?) -> String {
            if let data = data {
                return data.base64EncodedString()
            }
            return ""
        }
        
        if types.contains(where: { $0 == .fuel }) {
            let request: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
            if let fuelEntries = try? context.fetch(request) {
                for entry in fuelEntries {
                    var row: [String] = []
                    row.append("FuelEntry")
                    row.append(dateFormatter.string(from: entry.date))
                    row.append("\(entry.isDiesel)")
                    row.append("\(entry.isAdBlue)")
                    row.append("\(entry.currentKm)")
                    row.append("\(entry.liters)")
                    row.append("\(entry.costPerLiter)")
                    row.append("\(entry.totalCost)")
                    row.append("") // costPerBottle
                    row.append("") // bottleCount
                    row.append("") // category
                    row.append("") // details
                    row.append("") // cost
                    row.append(entry.latitude != 0 ? "\(entry.latitude)" : "")
                    row.append(entry.longitude != 0 ? "\(entry.longitude)" : "")
                    row.append(encodeReceiptData(entry.receiptData))
                    rows.append(row.joined(separator: "\t"))
                }
            }
        }
        
        if types.contains(where: { $0 == .gas }) {
            let request: NSFetchRequest<GasEntry> = GasEntry.fetchRequest() as! NSFetchRequest<GasEntry>
            if let gasEntries = try? context.fetch(request) {
                for entry in gasEntries {
                    var row: [String] = []
                    row.append("GasEntry")
                    row.append(dateFormatter.string(from: entry.date))
                    row.append("") // isDiesel
                    row.append("") // isAdBlue
                    row.append("") // currentKm
                    row.append("") // liters
                    row.append("") // costPerLiter
                    row.append("") // totalCost
                    row.append("\(entry.costPerBottle)")
                    row.append("\(entry.bottleCount)")
                    row.append("") // category
                    row.append("") // details
                    row.append("") // cost
                    row.append(entry.latitude != 0 ? "\(entry.latitude)" : "")
                    row.append(entry.longitude != 0 ? "\(entry.longitude)" : "")
                    row.append(encodeReceiptData(entry.receiptData))
                    rows.append(row.joined(separator: "\t"))
                }
            }
        }
        
        if types.contains(where: { $0 == .other }) {
            let request: NSFetchRequest<OtherEntry> = OtherEntry.fetchRequest() as! NSFetchRequest<OtherEntry>
            if let otherEntries = try? context.fetch(request) {
                for entry in otherEntries {
                    var row: [String] = []
                    row.append("OtherEntry")
                    row.append(dateFormatter.string(from: entry.date))
                    row.append("") // isDiesel
                    row.append("") // isAdBlue
                    row.append("") // currentKm
                    row.append("") // liters
                    row.append("") // costPerLiter
                    row.append("") // totalCost
                    row.append("") // costPerBottle
                    row.append("") // bottleCount
                    row.append(entry.category)
                    row.append(entry.details ?? "")
                    row.append("\(entry.cost)")
                    row.append(entry.latitude != 0 ? "\(entry.latitude)" : "")
                    row.append(entry.longitude != 0 ? "\(entry.longitude)" : "")
                    row.append(encodeReceiptData(entry.receiptData))
                    rows.append(row.joined(separator: "\t"))
                }
            }
        }
        
        return rows.joined(separator: "\n")
    }
    
    /// Funktion zur Korrektur von GPS-Werten in FuelEntry, GasEntry und OtherEntry in Core Data.
    /// Diese Funktion wird in einem Hintergrundkontext ausgeführt, um den Hauptthread nicht zu blockieren.
    static func correctGPSValues(in mainContext: NSManagedObjectContext) {
        let container = PersistenceController.shared.container
        let bgContext = container.newBackgroundContext()
        bgContext.perform {
            let fuelRequest: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
            let gasRequest: NSFetchRequest<GasEntry> = GasEntry.fetchRequest() as! NSFetchRequest<GasEntry>
            let otherRequest: NSFetchRequest<OtherEntry> = OtherEntry.fetchRequest() as! NSFetchRequest<OtherEntry>
            do {
                let fuelEntries = try bgContext.fetch(fuelRequest)
                let gasEntries = try bgContext.fetch(gasRequest)
                let otherEntries = try bgContext.fetch(otherRequest)
                var didChange = false
                
                for entry in fuelEntries {
                    // Hier könnten bei Bedarf Korrekturen vorgenommen werden.
                    // Aktuell wird nur geloggt, falls Werte 0 sind.
                    if entry.latitude == 0 || entry.longitude == 0 {
                        print("FuelEntry \(entry.id) hat fehlerhafte GPS-Daten: Lat=\(entry.latitude), Lon=\(entry.longitude)")
                        // Hier könnte man einen Default-Wert setzen, z. B. den Nutzerstandort, falls verfügbar.
                        // entry.latitude = <default value>
                        // entry.longitude = <default value>
                        didChange = true
                    }
                }
                for entry in gasEntries {
                    if entry.latitude == 0 || entry.longitude == 0 {
                        print("GasEntry \(entry.id) hat fehlerhafte GPS-Daten: Lat=\(entry.latitude), Lon=\(entry.longitude)")
                        didChange = true
                    }
                }
                for entry in otherEntries {
                    if entry.latitude == 0 || entry.longitude == 0 {
                        print("OtherEntry \(entry.id) hat fehlerhafte GPS-Daten: Lat=\(entry.latitude), Lon=\(entry.longitude)")
                        didChange = true
                    }
                }
                
                if didChange && bgContext.hasChanges {
                    try bgContext.save()
                }
            } catch {
                print("Fehler beim Korrigieren der GPS-Daten im Hintergrund: \(error)")
            }
            // Änderungen in den Hauptkontext übernehmen
            mainContext.perform {
                do {
                    try mainContext.save()
                } catch {
                    print("Fehler beim Übernehmen der Hintergrundänderungen: \(error)")
                }
            }
        }
    }
}
