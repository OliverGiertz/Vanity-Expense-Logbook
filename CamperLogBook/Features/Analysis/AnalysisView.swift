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
    var period: String  // z. B. "Jan 2023"
    var cost: Double
    var type: String    // z. B. "Tankbeleg", "Gaskosten", "Ver-/Entsorgung", "Sonstige"
}

struct AnalysisView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedChartType: ChartType = .bar
    @State private var data: [AnalysisData] = []
    @State private var isLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()

    private static let monthDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

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
                .onChange(of: startDate) { _ in scheduleLoadData() }
                .onChange(of: endDate) { _ in scheduleLoadData() }

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

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
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
                }

                Spacer()
            }
            .navigationTitle("Auswertung")
            .onAppear { scheduleLoadData() }
            .onDisappear {
                loadTask?.cancel()
                loadTask = nil
            }
        }
    }

    private func scheduleLoadData() {
        loadTask?.cancel()
        isLoading = true

        let start = startDate
        let end = endDate

        loadTask = Task {
            let context = PersistenceController.shared.container.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            do {
                let aggregatedData = try await context.perform {
                    var tempData: [String: [String: Double]] = [:]

                    let fuel = try fetchFuelData(in: context, start: start, end: end)
                    let gas = try fetchGasData(in: context, start: start, end: end)
                    let service = try fetchServiceData(in: context, start: start, end: end)
                    let other = try fetchOtherData(in: context, start: start, end: end)

                    merge(type: "Tankbeleg", values: fuel, into: &tempData)
                    merge(type: "Gaskosten", values: gas, into: &tempData)
                    merge(type: "Ver-/Entsorgung", values: service, into: &tempData)
                    merge(type: "Sonstige", values: other, into: &tempData)

                    return buildAnalysisData(from: tempData)
                }

                guard !Task.isCancelled else { return }
                await MainActor.run {
                    data = aggregatedData
                    isLoading = false
                }
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "AnalysisView loadData failed")
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    data = []
                    isLoading = false
                }
            }
        }
    }

    private func fetchFuelData(in context: NSManagedObjectContext, start: Date, end: Date) throws -> [String: Double] {
        let request = NSFetchRequest<NSDictionary>(entityName: "FuelEntry")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["date", "totalCost"]
        let rows = try context.fetch(request)
        return aggregate(rows: rows) { row in
            (row["date"] as? Date, row["totalCost"] as? Double)
        }
    }

    private func fetchGasData(in context: NSManagedObjectContext, start: Date, end: Date) throws -> [String: Double] {
        let request = NSFetchRequest<NSDictionary>(entityName: "GasEntry")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["date", "costPerBottle", "bottleCount"]
        let rows = try context.fetch(request)
        return aggregate(rows: rows) { row in
            guard let date = row["date"] as? Date else { return nil }
            let price = (row["costPerBottle"] as? NSNumber)?.doubleValue ?? 0
            let count = (row["bottleCount"] as? NSNumber)?.doubleValue ?? 0
            return (date, price * count)
        }
    }

    private func fetchServiceData(in context: NSManagedObjectContext, start: Date, end: Date) throws -> [String: Double] {
        let request = NSFetchRequest<NSDictionary>(entityName: "ServiceEntry")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["date", "cost"]
        let rows = try context.fetch(request)
        return aggregate(rows: rows) { row in
            let cost = (row["cost"] as? NSNumber)?.doubleValue
            return (row["date"] as? Date, cost)
        }
    }

    private func fetchOtherData(in context: NSManagedObjectContext, start: Date, end: Date) throws -> [String: Double] {
        let request = NSFetchRequest<NSDictionary>(entityName: "OtherEntry")
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
        request.resultType = .dictionaryResultType
        request.propertiesToFetch = ["date", "cost"]
        let rows = try context.fetch(request)
        return aggregate(rows: rows) { row in
            let cost = (row["cost"] as? NSNumber)?.doubleValue
            return (row["date"] as? Date, cost)
        }
    }

    private func aggregate(rows: [NSDictionary], mapper: (NSDictionary) -> (Date?, Double?)?) -> [String: Double] {
        var result: [String: Double] = [:]
        for row in rows {
            guard let mapped = mapper(row),
                  let date = mapped.0,
                  let value = mapped.1 else { continue }
            let key = Self.monthKeyFormatter.string(from: date)
            result[key, default: 0] += value
        }
        return result
    }

    private func merge(type: String, values: [String: Double], into target: inout [String: [String: Double]]) {
        for (period, value) in values where value != 0 {
            target[period, default: [:]][type] = value
        }
    }

    private func buildAnalysisData(from groupedData: [String: [String: Double]]) -> [AnalysisData] {
        let sortedKeys = groupedData.keys.sorted { key1, key2 in
            if let date1 = Self.monthKeyFormatter.date(from: key1),
               let date2 = Self.monthKeyFormatter.date(from: key2) {
                return date1 < date2
            }
            return key1 < key2
        }

        var aggregatedData: [AnalysisData] = []
        for key in sortedKeys {
            let displayString: String
            if let date = Self.monthKeyFormatter.date(from: key) {
                displayString = Self.monthDisplayFormatter.string(from: date)
            } else {
                displayString = key
            }
            if let typeDict = groupedData[key] {
                for (type, cost) in typeDict {
                    aggregatedData.append(AnalysisData(period: displayString, cost: cost, type: type))
                }
            }
        }
        return aggregatedData
    }
}
