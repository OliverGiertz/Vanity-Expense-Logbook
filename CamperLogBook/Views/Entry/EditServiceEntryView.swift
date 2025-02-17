import SwiftUI
import CoreData

struct EditServiceEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var serviceEntry: ServiceEntry

    @State private var date: Date
    @State private var isSupply: Bool
    @State private var isDisposal: Bool
    @State private var cost: String
    @State private var receiptImage: UIImage?

    init(serviceEntry: ServiceEntry) {
        self.serviceEntry = serviceEntry
        _date = State(initialValue: serviceEntry.date)
        _isSupply = State(initialValue: serviceEntry.isSupply)
        _isDisposal = State(initialValue: serviceEntry.isDisposal)
        _cost = State(initialValue: String(serviceEntry.cost))
        if let data = serviceEntry.receiptData, let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
        } else {
            _receiptImage = State(initialValue: nil)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Datum")) {
                DatePicker("Datum", selection: $date, displayedComponents: .date)
                    .submitLabel(.done)
                    .onSubmit { KeyboardHelper.hideKeyboard() }
            }
            Section(header: Text("Art der Leistung")) {
                Toggle("Ver-sorgung", isOn: $isSupply)
                Toggle("Entsorgung", isOn: $isDisposal)
            }
            Section(header: Text("Kosten")) {
                TextField("Kosten", text: $cost)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { KeyboardHelper.hideKeyboard() }
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
        .navigationTitle("Ver-/Entsorgung bearbeiten")
    }

    private func saveChanges() {
        guard let costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) else { return }
        serviceEntry.date = date
        serviceEntry.isSupply = isSupply
        serviceEntry.isDisposal = isDisposal
        serviceEntry.cost = costValue
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern des Service-Eintrags: \(error)")
        }
    }

    private func deleteEntry() {
        viewContext.delete(serviceEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Löschen des Service-Eintrags: \(error)")
        }
    }
}

struct EditServiceEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let entry = ServiceEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.isSupply = true
        entry.isDisposal = false
        entry.cost = 30.0
        return NavigationView {
            EditServiceEntryView(serviceEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
