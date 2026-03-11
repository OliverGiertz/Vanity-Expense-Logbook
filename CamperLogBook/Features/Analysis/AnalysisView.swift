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

    @FetchRequest(
        entity: ExpenseCategory.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ExpenseCategory.name, ascending: true)]
    ) private var categories: FetchedResults<ExpenseCategory>

    @State private var selectedChartType: ChartType = .bar
    @State private var data: [AnalysisData] = []
    @State private var isLoading: Bool = false
    @State private var loadTask: Task<Void, Never>?

    private static let periodDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

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

    @State private var periodFilter: PeriodFilter = .year
    @State private var showDateRangePicker = false
    @State private var startDate: Date = {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
    }()
    @State private var endDate: Date = {
        let year = Calendar.current.component(.year, from: Date())
        return Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }()

    @State private var selectedCostTypes: Set<String> = ["Tankbeleg", "Gaskosten", "Ver-/Entsorgung", "Sonstige"]
    @State private var selectedCategory: String? = nil

    private var periodLabel: String {
        if periodFilter == .custom {
            return "\(Self.periodDateFormatter.string(from: startDate)) – \(Self.periodDateFormatter.string(from: endDate))"
        }
        return periodFilter.rawValue
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                                        if type == "Sonstige" { selectedCategory = nil }
                                    }
                                }
                            ))
                            .toggleStyle(.button)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 6)

                // Kategorie-Subfilter (nur wenn Sonstige aktiv und Kategorien vorhanden)
                if selectedCostTypes.contains("Sonstige") && !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button {
                                selectedCategory = nil
                            } label: {
                                Label("Alle", systemImage: selectedCategory == nil ? "checkmark" : "")
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedCategory == nil ? .accentColor : .secondary)

                            ForEach(categories, id: \.objectID) { cat in
                                let name = cat.name ?? ""
                                Button {
                                    selectedCategory = (selectedCategory == name) ? nil : name
                                } label: {
                                    Label(name, systemImage: selectedCategory == name ? "checkmark" : "")
                                }
                                .buttonStyle(.bordered)
                                .tint(selectedCategory == name ? .accentColor : .secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 4)
                }

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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Zeitraum", selection: $periodFilter) {
                            ForEach(PeriodFilter.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        if periodFilter == .custom {
                            Button {
                                showDateRangePicker = true
                            } label: {
                                Label(periodLabel, systemImage: "calendar.badge.clock")
                            }
                        }
                    } label: {
                        Label(
                            periodFilter == .custom ? "Datum" : periodFilter.rawValue,
                            systemImage: periodFilter != .all ? "calendar.badge.checkmark" : "calendar"
                        )
                    }
                    .onChange(of: periodFilter) { _, newValue in
                        applyPeriodPreset(newValue)
                        if newValue == .custom { showDateRangePicker = true }
                    }
                }
            }
            .sheet(isPresented: $showDateRangePicker) {
                CustomDateRangeSheet(startDate: $startDate, endDate: $endDate)
            }
            .onChange(of: showDateRangePicker) { _, isShowing in
                if !isShowing && periodFilter == .custom { scheduleLoadData() }
            }
            .onChange(of: selectedCostTypes) { _, _ in scheduleLoadData() }
            .onChange(of: selectedCategory) { _, _ in scheduleLoadData() }
            .onAppear { scheduleLoadData() }
            .onDisappear {
                loadTask?.cancel()
                loadTask = nil
            }
        }
    }

    private func applyPeriodPreset(_ period: PeriodFilter) {
        guard period != .custom else { return }
        let cal = Calendar.current
        let now = Date()
        switch period {
        case .all:
            startDate = cal.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? now
            endDate = now
        case .month:
            startDate = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            endDate = now
        case .quarter:
            let month = cal.component(.month, from: now)
            let qStart = ((month - 1) / 3) * 3 + 1
            startDate = cal.date(from: DateComponents(year: cal.component(.year, from: now), month: qStart, day: 1)) ?? now
            endDate = now
        case .year:
            let year = cal.component(.year, from: now)
            startDate = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            endDate = cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? now
        case .custom:
            break
        }
        scheduleLoadData()
    }

    private func scheduleLoadData() {
        loadTask?.cancel()
        isLoading = true

        let start = startDate
        let end = endDate
        let category = selectedCategory

        loadTask = Task {
            let context = PersistenceController.shared.container.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            do {
                let aggregatedData = try await context.perform {
                    var tempData: [String: [String: Double]] = [:]

                    let fuel = try fetchFuelData(in: context, start: start, end: end)
                    let gas = try fetchGasData(in: context, start: start, end: end)
                    let service = try fetchServiceData(in: context, start: start, end: end)
                    let other = try fetchOtherData(in: context, start: start, end: end, category: category)

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

    private func fetchOtherData(in context: NSManagedObjectContext, start: Date, end: Date, category: String?) throws -> [String: Double] {
        let request = NSFetchRequest<NSDictionary>(entityName: "OtherEntry")
        if let cat = category {
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND category == %@", start as NSDate, end as NSDate, cat)
        } else {
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
        }
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
