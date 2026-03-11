import SwiftUI
import CoreData

// MARK: - Filter Types

enum EntryTypeFilter: String, CaseIterable, Identifiable {
    case all     = "Alle"
    case fuel    = "Tankbeleg"
    case gas     = "Gas"
    case service = "Ver-/Entsorgung"
    case other   = "Sonstige"
    var id: String { rawValue }
}

enum PeriodFilter: String, CaseIterable, Identifiable {
    case all     = "Gesamt"
    case month   = "Dieser Monat"
    case quarter = "Quartal"
    case year    = "Dieses Jahr"
    var id: String { rawValue }

    var startDate: Date? {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .all:
            return nil
        case .month:
            return cal.date(from: cal.dateComponents([.year, .month], from: now))
        case .quarter:
            let month = cal.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            return cal.date(from: DateComponents(year: cal.component(.year, from: now), month: quarterStartMonth, day: 1))
        case .year:
            return cal.date(from: DateComponents(year: cal.component(.year, from: now), month: 1, day: 1))
        }
    }
}

// MARK: - Unified Entry Type

enum AnyExpenseEntry: Identifiable {
    case fuel(FuelEntry)
    case gas(GasEntry)
    case service(ServiceEntry)
    case other(OtherEntry)

    var id: NSManagedObjectID {
        switch self {
        case .fuel(let e):    return e.objectID
        case .gas(let e):     return e.objectID
        case .service(let e): return e.objectID
        case .other(let e):   return e.objectID
        }
    }

    var date: Date {
        switch self {
        case .fuel(let e):    return e.date
        case .gas(let e):     return e.date
        case .service(let e): return e.date
        case .other(let e):   return e.date
        }
    }

    var amount: Double {
        switch self {
        case .fuel(let e):    return e.totalCost
        case .gas(let e):     return e.costPerBottle * Double(e.bottleCount)
        case .service(let e): return e.cost
        case .other(let e):   return e.cost
        }
    }

    var icon: String {
        switch self {
        case .fuel:    return "fuelpump.fill"
        case .gas:     return "flame.fill"
        case .service: return "drop.fill"
        case .other:   return "doc.text.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .fuel:    return .blue
        case .gas:     return .orange
        case .service: return .teal
        case .other:   return .purple
        }
    }

    var title: String {
        switch self {
        case .fuel(let e):
            return e.fuelType.isEmpty ? "Tankbeleg" : e.fuelType
        case .gas:
            return "Gas"
        case .service(let e):
            if e.isSupply && e.isDisposal { return "Ver- & Entsorgung" }
            if e.isSupply   { return "Versorgung" }
            if e.isDisposal { return "Entsorgung" }
            return "Ver-/Entsorgung"
        case .other(let e):
            return e.category.isEmpty ? "Sonstige" : e.category
        }
    }

    var subtitle: String? {
        switch self {
        case .fuel(let e):
            return "\(e.currentKm) km"
        case .gas(let e):
            return "\(e.bottleCount) Flasche\(e.bottleCount == 1 ? "" : "n")"
        case .service:
            return nil
        case .other(let e):
            let details = e.details ?? ""
            return details.isEmpty ? nil : details
        }
    }

    var typeFilter: EntryTypeFilter {
        switch self {
        case .fuel:    return .fuel
        case .gas:     return .gas
        case .service: return .service
        case .other:   return .other
        }
    }

    func delete(in context: NSManagedObjectContext) throws {
        switch self {
        case .fuel(let e):    context.delete(e)
        case .gas(let e):     context.delete(e)
        case .service(let e): context.delete(e)
        case .other(let e):   context.delete(e)
        }
        try context.save()
    }

    @ViewBuilder
    func editView() -> some View {
        switch self {
        case .fuel(let e):    EditFuelEntryView(fuelEntry: e)
        case .gas(let e):     EditGasEntryView(gasEntry: e)
        case .service(let e): EditServiceEntryView(serviceEntry: e)
        case .other(let e):   EditOtherEntryView(otherEntry: e)
        }
    }
}

// MARK: - Row View

private let rowDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .short
    return f
}()

struct ExpenseListRow: View {
    let entry: AnyExpenseEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .foregroundColor(entry.iconColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body)
                if let sub = entry.subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f €", entry.amount))
                    .font(.body.monospacedDigit())
                Text(entry.date, formatter: rowDateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Main View

struct ExpenseListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: FuelEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: false)]
    ) private var fuelEntries: FetchedResults<FuelEntry>

    @FetchRequest(
        entity: GasEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GasEntry.date, ascending: false)]
    ) private var gasEntries: FetchedResults<GasEntry>

    @FetchRequest(
        entity: ServiceEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ServiceEntry.date, ascending: false)]
    ) private var serviceEntries: FetchedResults<ServiceEntry>

    @FetchRequest(
        entity: OtherEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \OtherEntry.date, ascending: false)]
    ) private var otherEntries: FetchedResults<OtherEntry>

    @State private var typeFilter: EntryTypeFilter = .all
    @State private var periodFilter: PeriodFilter = .all
    @State private var pendingDelete: AnyExpenseEntry? = nil

    private var filteredEntries: [AnyExpenseEntry] {
        var all: [AnyExpenseEntry] = []
        if typeFilter == .all || typeFilter == .fuel    { all += fuelEntries.map    { .fuel($0) } }
        if typeFilter == .all || typeFilter == .gas     { all += gasEntries.map     { .gas($0) } }
        if typeFilter == .all || typeFilter == .service { all += serviceEntries.map { .service($0) } }
        if typeFilter == .all || typeFilter == .other   { all += otherEntries.map   { .other($0) } }
        if let start = periodFilter.startDate {
            all = all.filter { $0.date >= start }
        }
        return all.sorted { $0.date > $1.date }
    }

    private var isFiltered: Bool {
        typeFilter != .all || periodFilter != .all
    }

    var body: some View {
        NavigationView {
            List {
                if filteredEntries.isEmpty {
                    Text("Keine Einträge gefunden.")
                        .foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredEntries) { entry in
                        NavigationLink(destination: entry.editView()) {
                            ExpenseListRow(entry: entry)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = entry
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ausgaben")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Zeitraum", selection: $periodFilter) {
                            ForEach(PeriodFilter.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                    } label: {
                        Label(periodFilter.rawValue, systemImage: "calendar")
                            .symbolVariant(periodFilter != .all ? .fill : .none)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Typ", selection: $typeFilter) {
                            ForEach(EntryTypeFilter.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                    } label: {
                        Image(systemName: isFiltered
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .confirmationDialog(
                "Eintrag löschen?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    if let entry = pendingDelete {
                        deleteEntry(entry)
                    }
                    pendingDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text("Dieser Eintrag wird unwiderruflich gelöscht.")
            }
        }
    }

    private func deleteEntry(_ entry: AnyExpenseEntry) {
        HapticFeedback.impactMedium()
        do {
            try entry.delete(in: viewContext)
            HapticFeedback.success()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Löschen ExpenseListView")
            HapticFeedback.error()
        }
    }
}

// MARK: - Preview

struct ExpenseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseListView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
