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
    
    // Zusätzliche unterstützte Datumsformate (Fallbacks)
    private static let fallbackDateFormatters: [DateFormatter] = {
        let f1 = DateFormatter(); f1.dateFormat = "dd.MM.yyyy"
        let f2 = DateFormatter(); f2.dateFormat = "yyyy-MM-dd"
        return [f1, f2]
    }()
    
    private static func parseDate(_ string: String) -> Date? {
        if let d = dateFormatter.date(from: string) { return d }
        for f in fallbackDateFormatters {
            if let d = f.date(from: string) { return d }
        }
        return nil
    }
    
    /// Hilfsfunktion, die einen String normalisiert, indem alle Kommas durch Punkte ersetzt werden,
    /// und anschließend versucht, einen Double-Wert zu erzeugen.
    private static func parseDouble(from string: String) -> Double? {
        let normalized = string.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(normalized)
    }
    
    /// Robustere Interpretation von Booleans
    private static func parseBool(from string: String) -> Bool? {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["1", "true", "yes", "y", "ja", "wahr"].contains(s) { return true }
        if ["0", "false", "no", "n", "nein", "falsch"].contains(s) { return false }
        return nil
    }
    
    /// Importiert eine CSV-Datei (Semikolon-getrennt) und erstellt Core Data-Objekte.
    /// - Parameters:
    ///   - type: Der zu importierende Eintragstyp.
    ///   - url: Die URL der CSV-Datei.
    ///   - context: Der NSManagedObjectContext.
    /// - Returns: Anzahl der importierten Einträge.
    /// Importiert eine CSV-Datei und gibt die Anzahl importierter Einträge zurück.
    /// Für detaillierte Fehlerinformationen zu übersprungenen Zeilen: `importCSVDetailed`.
    static func importCSV(for type: CSVHelperEntryType, from url: URL, in context: NSManagedObjectContext) throws -> Int {
        try importCSVDetailed(for: type, from: url, in: context).imported
    }

    /// Importiert eine CSV-Datei und liefert neben der Import-Anzahl alle übersprungenen Zeilen
    /// mit dem jeweiligen Grund, damit Aufrufer gezielt Feedback geben können.
    static func importCSVDetailed(for type: CSVHelperEntryType, from url: URL, in context: NSManagedObjectContext) throws -> ImportResult {
        var content = try String(contentsOf: url, encoding: .utf8)
        if content.hasPrefix("\u{feff}") { content.removeFirst() }
        let rawLines = content.components(separatedBy: .newlines)
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return ImportResult(imported: 0, skippedRows: []) }

        let delimiter: Character
        if headerLine.contains("\t") { delimiter = "\t" }
        else if headerLine.contains(";") { delimiter = ";" }
        else if headerLine.contains(",") { delimiter = "," }
        else { delimiter = "\t" }

        let headers = headerLine.split(separator: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
        var importedCount = 0
        var skipped: [(row: [String: String], reason: String)] = []

        for line in lines.dropFirst() {
            let values = line.split(separator: delimiter, omittingEmptySubsequences: false).map { String($0) }
            if values.count < headers.count {
                skipped.append((row: ["_raw": line], reason: "Zu wenige Spalten (\(values.count) von \(headers.count))"))
                continue
            }
            var row = [String: String]()
            for (index, header) in headers.enumerated() where index < values.count {
                row[String(header)] = values[index]
            }
            let rowLower = Dictionary(uniqueKeysWithValues: row.map { ($0.key.lowercased(), $0.value) })

            if let entryTypeValue = rowLower["entrytype"], !entryTypeValue.isEmpty {
                let typeString = entryTypeValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let matchesType: Bool
                switch type {
                case .fuel:  matchesType = typeString == "fuelentry" || typeString == "fuel"
                case .gas:   matchesType = typeString == "gasentry"  || typeString == "gas"
                case .other: matchesType = typeString == "otherentry" || typeString == "other"
                }
                if !matchesType {
                    skipped.append((row: rowLower, reason: "entryType '\(typeString)' passt nicht zu gesuchtem Typ"))
                    continue
                }
            }

            do {
                let imported: Bool
                switch type {
                case .fuel:  imported = (try importFuelEntry(from:  rowLower, in: context)) != nil
                case .gas:   imported = (try importGasEntry(from:   rowLower, in: context)) != nil
                case .other: imported = (try importOtherEntry(from: rowLower, in: context)) != nil
                }
                if imported { importedCount += 1 }
                else { skipped.append((row: rowLower, reason: "Pflichtfeld fehlt (z.B. Datum)")) }
            } catch {
                skipped.append((row: rowLower, reason: error.localizedDescription))
            }
        }
        if context.hasChanges { try context.save() }
        return ImportResult(imported: importedCount, skippedRows: skipped)
    }

    // MARK: - Import result types

    struct ImportSummary {
        let fuel: Int
        let gas: Int
        let other: Int
        var total: Int { fuel + gas + other }
    }

    struct ImportResult {
        let imported: Int
        let skippedRows: [(row: [String: String], reason: String)]
    }

    /// Importiert eine CSV mit gemischten Einträgen. Entscheidet pro Zeile anhand der Spalte "entryType" (oder heuristisch), welcher Typ importiert wird.
    static func importCSVAllTypes(from url: URL, in context: NSManagedObjectContext) throws -> ImportSummary {
        var content = try String(contentsOf: url, encoding: .utf8)
        if content.hasPrefix("\u{feff}") { content.removeFirst() }
        let rawLines = content.components(separatedBy: .newlines)
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let headerLine = lines.first else { return .init(fuel: 0, gas: 0, other: 0) }

        let delimiter: Character
        if headerLine.contains("\t") { delimiter = "\t" } else if headerLine.contains(";") { delimiter = ";" } else if headerLine.contains(",") { delimiter = "," } else { delimiter = "\t" }

        let headers = headerLine.split(separator: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
        let headersLower = headers.map { $0.lowercased() }

        var fuelCount = 0
        var gasCount = 0
        var otherCount = 0

        for line in lines.dropFirst() {
            let values = line.split(separator: delimiter, omittingEmptySubsequences: false).map { String($0) }
            if values.isEmpty { continue }
            var row = [String: String]()
            for (index, header) in headers.enumerated() where index < values.count {
                row[String(header)] = values[index]
            }
            let rowLower = Dictionary(uniqueKeysWithValues: row.map { ($0.key.lowercased(), $0.value) })

            // Typ-Ermittlung: bevorzugt entryType-Spalte, sonst heuristisch
            let typeLower = rowLower["entrytype"]?.lowercased()
            let resolvedType: CSVHelperEntryType? = {
                if let t = typeLower {
                    if t == "fuelentry" || t == "fuel" { return .fuel }
                    if t == "gasentry" || t == "gas" { return .gas }
                    if t == "otherentry" || t == "other" { return .other }
                }
                // Heuristik: anhand vorhandener Spalten/werte
                let hasFuelCols = headersLower.contains("liters") || headersLower.contains("currentkm") || headersLower.contains("costperliter") || headersLower.contains("totalcost")
                let hasGasCols = headersLower.contains("costperbottle") || headersLower.contains("bottlecount")
                let hasOtherCols = headersLower.contains("category") || headersLower.contains("cost")
                if hasFuelCols { return .fuel }
                if hasGasCols { return .gas }
                if hasOtherCols { return .other }
                return nil
            }()

            guard let type = resolvedType else { continue }

            switch type {
            case .fuel:
                if (try? importFuelEntry(from: rowLower, in: context)) != nil { fuelCount += 1 }
            case .gas:
                if (try? importGasEntry(from: rowLower, in: context)) != nil { gasCount += 1 }
            case .other:
                if (try? importOtherEntry(from: rowLower, in: context)) != nil { otherCount += 1 }
            }
        }

        if context.hasChanges { try context.save() }
        return .init(fuel: fuelCount, gas: gasCount, other: otherCount)
    }
    
    private static func importFuelEntry(from row: [String: String], in context: NSManagedObjectContext) throws -> FuelEntry? {
        // Erwarteter Header: date;isdiesel;isadblue;currentkm;liters;costperliter;totalcost;latitude;longitude;receiptdata
        guard let dateString = row["date"], let date = parseDate(dateString) else { return nil }
        let entry = FuelEntry(context: context)
        entry.id = UUID()
        entry.date = date
        
        if let isDieselStr = row["isdiesel"], let b = parseBool(from: isDieselStr) { entry.isDiesel = b }
        if let isAdBlueStr = row["isadblue"], let b = parseBool(from: isAdBlueStr) { entry.isAdBlue = b }
        // isFull defaults to true for legacy imports without the column
        entry.isFull = row["isfull"].flatMap { parseBool(from: $0) } ?? true
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
        guard let dateString = row["date"], let date = parseDate(dateString) else { return nil }
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
        guard let dateString = row["date"], let date = parseDate(dateString) else { return nil }
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
        let header = ["entryType", "date", "isDiesel", "isAdBlue", "isFull", "currentKm", "liters", "costPerLiter", "totalCost", "costPerBottle", "bottleCount", "category", "details", "cost", "latitude", "longitude", "receiptData"]
        var rows = [header.joined(separator: "\t")]
        
        func encodeReceiptData(_ data: Data?) -> String {
            if let data = data {
                return data.base64EncodedString()
            }
            return ""
        }
        
        if types.contains(where: { $0 == .fuel }) {
            let request: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
            if let fuelEntries = try? context.fetch(request) {
                for entry in fuelEntries {
                    var row: [String] = []
                    row.append("FuelEntry")
                    row.append(dateFormatter.string(from: entry.date))
                    row.append("\(entry.isDiesel)")
                    row.append("\(entry.isAdBlue)")
                    row.append("\(entry.isFull)")
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
            let request: NSFetchRequest<GasEntry> = NSFetchRequest(entityName: "GasEntry")
            if let gasEntries = try? context.fetch(request) {
                for entry in gasEntries {
                    var row: [String] = []
                    row.append("GasEntry")
                    row.append(dateFormatter.string(from: entry.date))
                    row.append("") // isDiesel
                    row.append("") // isAdBlue
                    row.append("") // isFull
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
            let request: NSFetchRequest<OtherEntry> = NSFetchRequest(entityName: "OtherEntry")
            if let otherEntries = try? context.fetch(request) {
                for entry in otherEntries {
                    var row: [String] = []
                    row.append("OtherEntry")
                    row.append(dateFormatter.string(from: entry.date))
                    row.append("") // isDiesel
                    row.append("") // isAdBlue
                    row.append("") // isFull
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
            let fuelRequest: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
            let gasRequest: NSFetchRequest<GasEntry> = NSFetchRequest(entityName: "GasEntry")
            let otherRequest: NSFetchRequest<OtherEntry> = NSFetchRequest(entityName: "OtherEntry")
            do {
                let fuelEntries = try bgContext.fetch(fuelRequest)
                let gasEntries = try bgContext.fetch(gasRequest)
                let otherEntries = try bgContext.fetch(otherRequest)
                var didChange = false
                
                for entry in fuelEntries where entry.latitude == 0 || entry.longitude == 0 {
                    ErrorLogger.shared.log(message: "FuelEntry \(entry.id) hat GPS (0,0)")
                    didChange = true
                }
                for entry in gasEntries where entry.latitude == 0 || entry.longitude == 0 {
                    ErrorLogger.shared.log(message: "GasEntry \(entry.id) hat GPS (0,0)")
                    didChange = true
                }
                for entry in otherEntries where entry.latitude == 0 || entry.longitude == 0 {
                    ErrorLogger.shared.log(message: "OtherEntry \(entry.id) hat GPS (0,0)")
                    didChange = true
                }

                if didChange && bgContext.hasChanges {
                    try bgContext.save()
                }
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "correctGPSValues Hintergrundkontext")
            }
            mainContext.perform {
                do {
                    try mainContext.save()
                } catch {
                    ErrorLogger.shared.log(error: error, additionalInfo: "correctGPSValues Hauptkontext")
                }
            }
        }
    }
}
