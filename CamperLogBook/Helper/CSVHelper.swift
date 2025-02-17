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
            // Konvertiere alle Keys in Kleinbuchstaben, um Probleme mit Groß-/Kleinschreibung zu vermeiden.
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
        // Erwarteter Header: Date;IsDiesel;IsAdBlue;currentKm;liters;costPerLiter;totalCost
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
        if let litersStr = row["liters"] {
            let lit = litersStr.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
            if let liters = Double(lit) {
                entry.liters = liters
            }
        }
        if let costPerLiterStr = row["costperliter"] {
            let costStr = costPerLiterStr.replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if let cost = Double(costStr) {
                entry.costPerLiter = cost
            }
        }
        if let totalCostStr = row["totalcost"] {
            let totalStr = totalCostStr
                .replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if let total = Double(totalStr) {
                entry.totalCost = total
            }
        }
        if let latitudeStr = row["latitude"], let lat = Double(latitudeStr.trimmingCharacters(in: .whitespaces)) {
            entry.latitude = lat
        }
        if let longitudeStr = row["longitude"], let lon = Double(longitudeStr.trimmingCharacters(in: .whitespaces)) {
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
            let costStr = costPerBottleStr.replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if let costPerBottle = Double(costStr) {
                entry.costPerBottle = costPerBottle
            }
        }
        if let bottleCountStr = row["bottlecount"]?.trimmingCharacters(in: .whitespaces),
           let count = Int64(bottleCountStr) {
            entry.bottleCount = count
        }
        if let latitudeStr = row["latitude"], let lat = Double(latitudeStr.trimmingCharacters(in: .whitespaces)) {
            entry.latitude = lat
        }
        if let longitudeStr = row["longitude"], let lon = Double(longitudeStr.trimmingCharacters(in: .whitespaces)) {
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
            let costClean = costStr.replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if let cost = Double(costClean) {
                entry.cost = cost
            }
        }
        if let latitudeStr = row["latitude"], let lat = Double(latitudeStr.trimmingCharacters(in: .whitespaces)) {
            entry.latitude = lat
        }
        if let longitudeStr = row["longitude"], let lon = Double(longitudeStr.trimmingCharacters(in: .whitespaces)) {
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
}
