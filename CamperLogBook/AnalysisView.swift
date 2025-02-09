import SwiftUI
import Charts
import CoreData

enum ChartType: String, CaseIterable, Identifiable {
    case bar = "Balkendiagramm"
    case line = "Liniendiagramm"
    var id: String { self.rawValue }
}

struct AnalysisData: Identifiable {
    var id = UUID()
    var period: String  // z. B. "Jan 2023"
    var cost: Double
    var type: String    // z. B. "Tankbeleg", "Gaskosten", "Ver-/Entsorgung", "Sonstige"
}

struct AnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedChartType: ChartType = .bar
    @State private var data: [AnalysisData] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Picker("Diagrammtyp", selection: $selectedChartType) {
                    ForEach(ChartType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Chart(data) { item in
                    if selectedChartType == .bar {
                        BarMark(
                            x: .value("Monat", item.period),
                            y: .value("Kosten", item.cost)
                        )
                        .foregroundStyle(by: .value("Typ", item.type))
                    } else {
                        LineMark(
                            x: .value("Monat", item.period),
                            y: .value("Kosten", item.cost)
                        )
                        .foregroundStyle(by: .value("Typ", item.type))
                        .symbol(by: .value("Typ", item.type))
                    }
                }
                .chartLegend(.visible)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Auswertung")
            .onAppear(perform: loadData)
        }
    }
    
    private func loadData() {
        // Gruppierung nach Monat statt Jahr
        var tempData: [String: [String: Double]] = [:] // [MonatKey: [Typ: Kosten]]
        let groupingFormatter = DateFormatter()
        groupingFormatter.dateFormat = "yyyy-MM"  // z. B. "2023-01" als Gruppenschlüssel
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yyyy"   // z. B. "Jan 2023" für die Anzeige
        
        // Tankbelege
        let fuelRequest = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        if let fuelEntries = try? viewContext.fetch(fuelRequest) {
            for entry in fuelEntries {
                let key = groupingFormatter.string(from: entry.date)
                tempData[key, default: [:]]["Tankbeleg"] = (tempData[key]?["Tankbeleg"] ?? 0) + entry.totalCost
            }
        }
        
        // Gaskosten
        let gasRequest = GasEntry.fetchRequest() as! NSFetchRequest<GasEntry>
        if let gasEntries = try? viewContext.fetch(gasRequest) {
            for entry in gasEntries {
                let key = groupingFormatter.string(from: entry.date)
                let totalCost = entry.costPerBottle * Double(entry.bottleCount)
                tempData[key, default: [:]]["Gaskosten"] = (tempData[key]?["Gaskosten"] ?? 0) + totalCost
            }
        }
        
        // Ver- und Entsorgung
        let serviceRequest = ServiceEntry.fetchRequest() as! NSFetchRequest<ServiceEntry>
        if let serviceEntries = try? viewContext.fetch(serviceRequest) {
            for entry in serviceEntries {
                let key = groupingFormatter.string(from: entry.date)
                tempData[key, default: [:]]["Ver-/Entsorgung"] = (tempData[key]?["Ver-/Entsorgung"] ?? 0) + entry.cost
            }
        }
        
        // Sonstige Kosten
        let otherRequest = OtherEntry.fetchRequest() as! NSFetchRequest<OtherEntry>
        if let otherEntries = try? viewContext.fetch(otherRequest) {
            for entry in otherEntries {
                let key = groupingFormatter.string(from: entry.date)
                tempData[key, default: [:]]["Sonstige"] = (tempData[key]?["Sonstige"] ?? 0) + entry.cost
            }
        }
        
        var aggregatedData: [AnalysisData] = []
        // Schlüssel sortieren (um chronologische Reihenfolge zu erhalten)
        let sortedKeys = tempData.keys.sorted { key1, key2 in
            if let date1 = groupingFormatter.date(from: key1),
               let date2 = groupingFormatter.date(from: key2) {
                return date1 < date2
            }
            return key1 < key2
        }
        
        for key in sortedKeys {
            let displayString: String
            if let date = groupingFormatter.date(from: key) {
                displayString = displayFormatter.string(from: date)
            } else {
                displayString = key
            }
            if let typeDict = tempData[key] {
                for (type, cost) in typeDict {
                    aggregatedData.append(AnalysisData(period: displayString, cost: cost, type: type))
                }
            }
        }
        
        data = aggregatedData
    }
}

struct AnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        AnalysisView().environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
