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
    
    // Receipt options
    @State private var showingReceiptOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingPDFPicker = false
    @State private var showingScanner = false

    init(gasEntry: GasEntry) {
        self.gasEntry = gasEntry
        _date = State(initialValue: gasEntry.date)
        _costPerBottle = State(initialValue: String(gasEntry.costPerBottle))
        _bottleCount = State(initialValue: String(gasEntry.bottleCount))
        if gasEntry.receiptType == "image", let data = gasEntry.receiptData, let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
        } else if gasEntry.receiptType == "pdf", let data = gasEntry.receiptData {
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
                    Button("Aus Fotos wählen") { showingPhotoPicker = true }
                    Button("Aus Dateien (PDF) wählen") { showingPDFPicker = true }
                    Button("Kamera Scannen") { showingScanner = true }
                    Button("Abbrechen", role: .cancel) { }
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
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoPickerView { image in
                if let img = image {
                    receiptImage = img
                    pdfData = nil
                }
            }
        }
        .sheet(isPresented: $showingPDFPicker) {
            PDFDocumentPicker { url in
                if let url = url, let data = try? Data(contentsOf: url) {
                    pdfData = data
                    receiptImage = nil
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView { images in
                if !images.isEmpty {
                    if let pdf = PDFCreator.createPDF(from: images) {
                        pdfData = pdf
                        receiptImage = nil
                    }
                }
            }
        }
    }

    private func saveChanges() {
        guard let cost = Double(costPerBottle.replacingOccurrences(of: ",", with: ".")),
              let count = Int64(bottleCount) else { return }
        gasEntry.date = date
        gasEntry.costPerBottle = cost
        gasEntry.bottleCount = count
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
}

struct EditGasEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let entry = GasEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.costPerBottle = 2.0
        entry.bottleCount = 3
        entry.receiptType = "image"
        entry.receiptData = UIImage(systemName: "gas")?.jpegData(compressionQuality: 0.8)
        return NavigationView {
            EditGasEntryView(gasEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
