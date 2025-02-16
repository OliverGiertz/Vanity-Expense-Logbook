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
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?
    
    // Receipt options
    @State private var showingReceiptOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingPDFPicker = false
    @State private var showingScanner = false

    init(otherEntry: OtherEntry) {
        self.otherEntry = otherEntry
        _date = State(initialValue: otherEntry.date)
        _category = State(initialValue: otherEntry.category)
        _details = State(initialValue: otherEntry.details ?? "")
        _cost = State(initialValue: String(otherEntry.cost))
        if otherEntry.receiptType == "image", let data = otherEntry.receiptData, let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
        } else if otherEntry.receiptType == "pdf", let data = otherEntry.receiptData {
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
        .navigationTitle("Sonstiger Beleg bearbeiten")
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
        guard let costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) else { return }
        otherEntry.date = date
        otherEntry.category = category
        otherEntry.details = details
        otherEntry.cost = costValue
        if let pdfData = pdfData {
            otherEntry.receiptData = pdfData
            otherEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            otherEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            otherEntry.receiptType = "image"
        }
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
        entry.receiptType = "image"
        entry.receiptData = UIImage(systemName: "doc")?.jpegData(compressionQuality: 0.8)
        return NavigationView {
            EditOtherEntryView(otherEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
