import SwiftUI
import CoreData

struct EditOtherEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var otherEntry: OtherEntry

    @State private var date: Date
    @State private var category: String
    @State private var details: String
    @State private var cost: String

    init(otherEntry: OtherEntry) {
        self.otherEntry = otherEntry
        _date = State(initialValue: otherEntry.date)
        _category = State(initialValue: otherEntry.category)
        _details = State(initialValue: otherEntry.details ?? "")
        _cost = State(initialValue: String(otherEntry.cost))
    }

    var body: some View {
        Form {
            Section(header: Text("Datum")) {
                DatePicker("Datum", selection: $date, displayedComponents: .date)
            }
            Section(header: Text("Kategorie")) {
                TextField("Kategorie", text: $category)
            }
            Section(header: Text("Details")) {
                TextField("Details", text: $details)
            }
            Section(header: Text("Kosten")) {
                TextField("Kosten", text: $cost)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
            }
            Button("Speichern") {
                saveChanges()
            }
            Section {
                Button(role: .destructive) {
                    deleteEntry()
                } label: {
                    Text("Eintrag löschen")
                }
            }
        }
        .navigationTitle("Sonstiger Beleg bearbeiten")
    }

    private func saveChanges() {
        guard let costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) else { return }
        otherEntry.date = date
        otherEntry.category = category
        otherEntry.details = details
        otherEntry.cost = costValue
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
    
    private func deleteEntry() {
        viewContext.delete(otherEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Löschen: \(error)")
        }
    }
}

struct EditOtherEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let entry = OtherEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.category = "Ausstattung"
        entry.details = "Beispieltext"
        entry.cost = 25.0
        return NavigationView {
            EditOtherEntryView(otherEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
