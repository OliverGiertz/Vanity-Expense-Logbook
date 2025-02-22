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
    @State private var pdfData: Data?
    // Neuer State für Frischwasser-Eingabe
    @State private var freshWaterText: String
    
    // Neuer State für die Belegvorschau
    @State private var showReceiptDetail = false

    init(serviceEntry: ServiceEntry) {
        self.serviceEntry = serviceEntry
        _date = State(initialValue: serviceEntry.date)
        _isSupply = State(initialValue: serviceEntry.isSupply)
        _isDisposal = State(initialValue: serviceEntry.isDisposal)
        _cost = State(initialValue: String(serviceEntry.cost))
        _freshWaterText = State(initialValue: String(serviceEntry.freshWater))
        if let data = serviceEntry.receiptData {
            if let image = UIImage(data: data) {
                _receiptImage = State(initialValue: image)
                _pdfData = State(initialValue: nil)
            } else {
                _receiptImage = State(initialValue: nil)
                _pdfData = State(initialValue: data)
            }
        } else {
            _receiptImage = State(initialValue: nil)
            _pdfData = State(initialValue: nil)
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
                Toggle("Versorgung", isOn: $isSupply)
                Toggle("Entsorgung", isOn: $isDisposal)
            }
            if isSupply {
                Section(header: Text("Frischwasser")) {
                    TextField("Getankte Frischwasser (Liter)", text: $freshWaterText)
                        .keyboardType(.decimalPad)
                }
            }
            Section(header: Text("Kosten")) {
                TextField("Kosten", text: $cost)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { KeyboardHelper.hideKeyboard() }
            }
            // Neue Belegvorschau (falls Beleg vorhanden)
            if receiptImage != nil || pdfData != nil {
                Section(header: Text("Belegvorschau")) {
                    Button(action: { showReceiptDetail = true }) {
                        if let image = receiptImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                        } else if pdfData != nil {
                            Image(systemName: "doc.richtext")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                        }
                    }
                }
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
        .sheet(isPresented: $showReceiptDetail) {
            NavigationView {
                ReceiptDetailView(receiptImage: receiptImage, pdfData: pdfData)
            }
        }
    }
    
    private func saveChanges() {
        guard let costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) else { return }
        serviceEntry.date = date
        serviceEntry.isSupply = isSupply
        serviceEntry.isDisposal = isDisposal
        serviceEntry.cost = costValue
        if isSupply {
            serviceEntry.freshWater = Double(freshWaterText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        } else {
            serviceEntry.freshWater = 0.0
        }
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
        entry.cost = 100.0
        entry.freshWater = 50.0
        entry.receiptData = UIImage(systemName: "doc")?.jpegData(compressionQuality: 0.8)
        return NavigationView {
            EditServiceEntryView(serviceEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
