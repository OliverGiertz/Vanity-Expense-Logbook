import SwiftUI
import CoreData

struct EditGasEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var gasEntry: GasEntry

    @State private var date: Date
    @State private var costPerBottle: String
    @State private var bottleCount: String

    init(gasEntry: GasEntry) {
        self.gasEntry = gasEntry
        _date = State(initialValue: gasEntry.date)
        _costPerBottle = State(initialValue: String(gasEntry.costPerBottle))
        _bottleCount = State(initialValue: String(gasEntry.bottleCount))
    }

    var body: some View {
        Form {
            Section(header: Text("Datum")) {
                DatePicker("Datum", selection: $date, displayedComponents: .date)
                    .submitLabel(.done)
                    .onSubmit { hideKeyboard() }
            }
            Section(header: Text("Gaskosten")) {
                TextField("Kosten pro Flasche", text: $costPerBottle)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { hideKeyboard() }
                TextField("Anzahl Flaschen", text: $bottleCount)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .onSubmit { hideKeyboard() }
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
        .navigationTitle("Gasbeleg bearbeiten")
    }

    private func saveChanges() {
        guard let cost = Double(costPerBottle.replacingOccurrences(of: ",", with: ".")),
              let count = Int64(bottleCount) else { return }
        gasEntry.date = date
        gasEntry.costPerBottle = cost
        gasEntry.bottleCount = count
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
    
    private func deleteEntry() {
        viewContext.delete(gasEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Löschen: \(error)")
        }
    }
}

struct EditGasEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let entry = GasEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.costPerBottle = 2.0
        entry.bottleCount = 3
        return NavigationView {
            EditGasEntryView(gasEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
