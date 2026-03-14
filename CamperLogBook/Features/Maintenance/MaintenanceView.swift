import SwiftUI
import CoreData

// MARK: - Urgency

enum MaintenanceUrgency {
    case due, soon, ok

    var color: Color {
        switch self {
        case .due:  return .red
        case .soon: return .orange
        case .ok:   return .green
        }
    }

    var icon: String {
        switch self {
        case .due:  return "exclamationmark.circle.fill"
        case .soon: return "clock.badge.exclamationmark.fill"
        case .ok:   return "checkmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .due:  return "Fällig"
        case .soon: return "Bald fällig"
        case .ok:   return "OK"
        }
    }
}

// MARK: - MaintenanceView

struct MaintenanceView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: MaintenanceInterval.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \MaintenanceInterval.createdAt, ascending: true)]
    ) private var intervals: FetchedResults<MaintenanceInterval>

    @FetchRequest(
        entity: FuelEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: false)]
    ) private var lastFuelEntries: FetchedResults<FuelEntry>

    @State private var showAddSheet = false
    @State private var editingInterval: MaintenanceInterval? = nil
    @State private var pendingDelete: MaintenanceInterval? = nil

    private var currentKm: Int64 { lastFuelEntries.first?.currentKm ?? 0 }

    var body: some View {
        NavigationView {
            List {
                if intervals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Keine Wartungsintervalle")
                            .foregroundColor(.secondary)
                        Text("Tippe auf + um ein Intervall hinzuzufügen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(intervals) { interval in
                        MaintenanceRow(interval: interval, currentKm: currentKm)
                            .contentShape(Rectangle())
                            .onTapGesture { editingInterval = interval }
                            .swipeActions(edge: .leading) {
                                Button {
                                    markDone(interval)
                                } label: {
                                    Label("Erledigt", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDelete = interval
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Wartung")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                MaintenanceFormSheet(interval: nil, currentKm: currentKm)
            }
            .sheet(item: $editingInterval) { interval in
                MaintenanceFormSheet(interval: interval, currentKm: currentKm)
            }
            .confirmationDialog("Intervall löschen?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Löschen", role: .destructive) {
                    if let item = pendingDelete { delete(item) }
                    pendingDelete = nil
                }
                Button("Abbrechen", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("Dieser Eintrag wird unwiderruflich gelöscht.")
            }
        }
    }

    private func markDone(_ interval: MaintenanceInterval) {
        interval.lastServiceDate = Date()
        interval.lastServiceKm = currentKm
        do {
            try viewContext.save()
            HapticFeedback.success()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "MaintenanceView markDone")
            HapticFeedback.error()
        }
    }

    private func delete(_ interval: MaintenanceInterval) {
        viewContext.delete(interval)
        do {
            try viewContext.save()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "MaintenanceView delete")
        }
    }
}

// MARK: - Row

private struct MaintenanceRow: View {
    let interval: MaintenanceInterval
    let currentKm: Int64

    private var urgency: MaintenanceUrgency {
        let kmUrgency: MaintenanceUrgency?
        if interval.intervalKm > 0 {
            let dueAt = interval.lastServiceKm + interval.intervalKm
            let remaining = dueAt - currentKm
            if remaining <= 0 { kmUrgency = .due }
            else if remaining <= 500 { kmUrgency = .soon }
            else { kmUrgency = .ok }
        } else { kmUrgency = nil }

        let dateUrgency: MaintenanceUrgency?
        if interval.intervalMonths > 0, let last = interval.lastServiceDate {
            let cal = Calendar.current
            if let dueDate = cal.date(byAdding: .month, value: Int(interval.intervalMonths), to: last) {
                let days = cal.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
                if days <= 0 { dateUrgency = .due }
                else if days <= 30 { dateUrgency = .soon }
                else { dateUrgency = .ok }
            } else { dateUrgency = .ok }
        } else { dateUrgency = nil }

        let both = [kmUrgency, dateUrgency].compactMap { $0 }
        if both.contains(.due) { return .due }
        if both.contains(.soon) { return .soon }
        if !both.isEmpty { return .ok }
        return .ok
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: urgency.icon)
                .foregroundColor(urgency.color)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(interval.name ?? "Wartung")
                    .font(.body)

                HStack(spacing: 8) {
                    if interval.intervalKm > 0 {
                        Text("alle \(interval.intervalKm) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if interval.intervalMonths > 0 {
                        Text("alle \(interval.intervalMonths) Monate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let last = interval.lastServiceDate {
                    Text("Zuletzt: \(Self.dateFormatter.string(from: last))" +
                         (interval.lastServiceKm > 0 ? " · \(interval.lastServiceKm) km" : ""))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(urgency.label)
                .font(.caption)
                .bold()
                .foregroundColor(urgency.color)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Form Sheet

struct MaintenanceFormSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let interval: MaintenanceInterval?
    let currentKm: Int64

    @State private var name: String = ""
    @State private var intervalKm: String = ""
    @State private var intervalMonths: String = ""
    @State private var lastServiceKm: String = ""
    @State private var lastServiceDate: Date = Date()
    @State private var hasLastService: Bool = false
    @State private var notes: String = ""

    private var isEditing: Bool { interval != nil }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bezeichnung")) {
                    TextField("z. B. Ölwechsel", text: $name)
                }

                Section(header: Text("Intervall")) {
                    HStack {
                        TextField("0", text: $intervalKm)
                            .keyboardType(.numberPad)
                        Text("km")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        TextField("0", text: $intervalMonths)
                            .keyboardType(.numberPad)
                        Text("Monate")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("Zuletzt gewartet")) {
                    Toggle("Datum angeben", isOn: $hasLastService)
                    if hasLastService {
                        DatePicker("Datum", selection: $lastServiceDate, displayedComponents: .date)
                        HStack {
                            TextField("Kilometerstand", text: $lastServiceKm)
                                .keyboardType(.numberPad)
                            Text("km")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Notizen")) {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Intervall bearbeiten" : "Neues Intervall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let i = interval else { return }
        name = i.name ?? ""
        intervalKm = i.intervalKm > 0 ? "\(i.intervalKm)" : ""
        intervalMonths = i.intervalMonths > 0 ? "\(i.intervalMonths)" : ""
        if let d = i.lastServiceDate {
            hasLastService = true
            lastServiceDate = d
            lastServiceKm = i.lastServiceKm > 0 ? "\(i.lastServiceKm)" : ""
        }
        notes = i.notes ?? ""
    }

    private func save() {
        let item = interval ?? MaintenanceInterval(context: viewContext)
        if interval == nil {
            item.id = UUID()
            item.createdAt = Date()
        }
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.intervalKm = Int64(intervalKm) ?? 0
        item.intervalMonths = Int64(intervalMonths) ?? 0
        item.notes = notes.isEmpty ? nil : notes
        item.lastServiceDate = hasLastService ? lastServiceDate : nil
        item.lastServiceKm = hasLastService ? (Int64(lastServiceKm) ?? 0) : 0

        do {
            try viewContext.save()
            HapticFeedback.success()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "MaintenanceFormSheet save")
            HapticFeedback.error()
        }
    }
}
