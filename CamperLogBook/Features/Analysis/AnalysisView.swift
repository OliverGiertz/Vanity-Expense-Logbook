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
    
    // Zeitraum-Auswahl: Standard = aktuelles Jahr
    @State private var startDate: Date = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? Date()
    }()
    @State private var endDate: Date = {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31)) ?? Date()
    }()
    
    // Auswahl der Kostentypen; Standard: alle ausgewählt
    @State private var selectedCostTypes: Set<String> = ["Tankbeleg", "Gaskosten", "Ver-/Entsorgung", "Sonstige"]
    
    var body: some View {
        NavigationView {
            VStack {
                // Zeitraum-Auswahl
                HStack {
                    DatePicker("Von", selection: $startDate, displayedComponents: .date)
                    DatePicker("Bis", selection: $endDate, displayedComponents: .date)
                }
                .padding(.horizontal)
                .onChange(of: startDate) { _ in
                    loadData()
                }
                .onChange(of: endDate) { _ in
                    loadData()
                }
                
                // Kostentyp-Auswahl
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(["Tankbeleg", "Gaskosten", "Ver-/Entsorgung", "Sonstige"], id: \.self) { type in
                            Toggle(type, isOn: Binding(
                                get: { selectedCostTypes.contains(type) },
                                set: { newValue in
                                    if newValue {
                                        selectedCostTypes.insert(type)
                                    } else {
                                        selectedCostTypes.remove(type)
                                    }
                                }
                            ))
                            .toggleStyle(.button)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 5)
                
                Picker("Diagrammtyp", selection: $selectedChartType) {
                    ForEach(ChartType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Chart(data.filter { selectedCostTypes.contains($0.type) }) { item in
                    if selectedChartType == .bar {
                        BarMark(
                            x: .value("Monat", item.period),
                            y: .value("Kosten", item.cost)
                        )
                        .foregroundStyle(by: .value("Typ", item.type))
                        .annotation(position: .top) {
                            Text("\(Int(ceil(item.cost)))")
                                .font(.caption)
                        }
                    } else {
                        LineMark(
                            x: .value("Monat", item.period),
                            y: .value("Kosten", item.cost)
                        )
                        .foregroundStyle(by: .value("Typ", item.type))
                        .symbol(by: .value("Typ", item.type))
                        .annotation(position: .top) {
                            Text("\(Int(ceil(item.cost)))")
                                .font(.caption)
                        }
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
        // Gruppierung nach Monat (als Schlüssel)
        var tempData: [String: [String: Double]] = [:] // [MonatKey: [Typ: Kosten]]
        let groupingFormatter = DateFormatter()
        groupingFormatter.dateFormat = "yyyy-MM"  // z. B. "2023-01"
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM yyyy"   // z. B. "Jan 2023"
        
        // FuelEntry (Tankbelege)
        let fuelRequest = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        fuelRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        if let fuelEntries = try? viewContext.fetch(fuelRequest) {
            for entry in fuelEntries {
                let key = groupingFormatter.string(from: entry.date)
                tempData[key, default: [:]]["Tankbeleg"] = (tempData[key]?["Tankbeleg"] ?? 0) + entry.totalCost
            }
        }
        
        // GasEntry (Gaskosten)
        let gasRequest = GasEntry.fetchRequest() as! NSFetchRequest<GasEntry>
        gasRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        if let gasEntries = try? viewContext.fetch(gasRequest) {
            for entry in gasEntries {
                let key = groupingFormatter.string(from: entry.date)
                let totalCost = entry.costPerBottle * Double(entry.bottleCount)
                tempData[key, default: [:]]["Gaskosten"] = (tempData[key]?["Gaskosten"] ?? 0) + totalCost
            }
        }
        
        // ServiceEntry (Ver- und Entsorgung)
        let serviceRequest = ServiceEntry.fetchRequest() as! NSFetchRequest<ServiceEntry>
        serviceRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        if let serviceEntries = try? viewContext.fetch(serviceRequest) {
            for entry in serviceEntries {
                let key = groupingFormatter.string(from: entry.date)
                tempData[key, default: [:]]["Ver-/Entsorgung"] = (tempData[key]?["Ver-/Entsorgung"] ?? 0) + entry.cost
            }
        }
        
        // OtherEntry (Sonstige Kosten)
        let otherRequest = OtherEntry.fetchRequest() as! NSFetchRequest<OtherEntry>
        otherRequest.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as NSDate, endDate as NSDate)
        if let otherEntries = try? viewContext.fetch(otherRequest) {
            for entry in otherEntries {
                let key = groupingFormatter.string(from: entry.date)
                tempData[key, default: [:]]["Sonstige"] = (tempData[key]?["Sonstige"] ?? 0) + entry.cost
            }
        }
        
        var aggregatedData: [AnalysisData] = []
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
