import SwiftUI
import CoreData

struct EditGasEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var gasEntry: GasEntry

    @State private var date: Date
    @State private var costPerBottle: String
    @State private var bottleCount: String
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?
    
    // Zustände für die Beleg-Auswahl
    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    
    // Neuer State für die Belegvorschau
    @State private var showReceiptDetail = false

    init(gasEntry: GasEntry) {
        self.gasEntry = gasEntry
        _date = State(initialValue: gasEntry.date)
        _costPerBottle = State(initialValue: String(gasEntry.costPerBottle))
        _bottleCount = State(initialValue: String(gasEntry.bottleCount))
        if gasEntry.receiptType == "image", let data = gasEntry.receiptData, let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
            _pdfData = State(initialValue: nil)
        } else if gasEntry.receiptType == "pdf", let data = gasEntry.receiptData {
            _receiptImage = State(initialValue: nil)
            _pdfData = State(initialValue: data)
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
            Section(header: Text("Standort")) {
                if let address = gasEntry.address, !address.isEmpty {
                    Text(address)
                } else {
                    Text("Lat: \(gasEntry.latitude), Lon: \(gasEntry.longitude)")
                }
            }
            Section(header: Text("Beleg (Bild/PDF)")) {
                if let image = receiptImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                } else if pdfData != nil {
                    Image(systemName: "doc.richtext")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                }
                Button("Beleg ändern") {
                    showingReceiptOptions = true
                }
                .confirmationDialog("Beleg Quelle wählen", isPresented: $showingReceiptOptions, titleVisibility: .visible) {
                    Button("Aus Fotos wählen") { receiptSource = .photo }
                    Button("Aus Dateien (PDF) wählen") { receiptSource = .pdf }
                    Button("Kamera Scannen") { receiptSource = .scanner }
                    Button("Abbrechen", role: .cancel) { }
                }
            }
            // Neue Belegvorschau
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
        .navigationTitle("Gasbeleg bearbeiten")
        .sheet(item: $receiptSource) { source in
            ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
        }
        .sheet(isPresented: $showReceiptDetail) {
            NavigationView {
                ReceiptDetailView(receiptImage: receiptImage, pdfData: pdfData)
            }
        }
    }
    
    private func saveChanges() {
        guard let cost = Double(costPerBottle.replacingOccurrences(of: ",", with: ".")),
              let count = Int64(bottleCount) else { return }
        gasEntry.date = date
        gasEntry.costPerBottle = cost
        gasEntry.bottleCount = count
        // Hier könnte man – falls benötigt – auch die Adresse neu ermitteln.
        // Wir verwenden hier den bereits gespeicherten Wert.
        if let pdfData = pdfData {
            gasEntry.receiptData = pdfData
            gasEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            gasEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            gasEntry.receiptType = "image"
        }
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        entry.address = "Beispielstraße 5, 54321 Beispielstadt"
        entry.receiptType = "image"
        entry.receiptData = UIImage(systemName: "gas")?.jpegData(compressionQuality: 0.8)
        return NavigationView {
            EditGasEntryView(gasEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
