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

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    @State private var showReceiptDetail = false

    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showMailView: Bool = false

    init(otherEntry: OtherEntry) {
        self.otherEntry = otherEntry
        _date = State(initialValue: otherEntry.date)
        _category = State(initialValue: otherEntry.category)
        _details = State(initialValue: otherEntry.details ?? "")
        _cost = State(initialValue: String(otherEntry.cost))
        if otherEntry.receiptType == "image",
           let data = otherEntry.receiptData,
           let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
            _pdfData = State(initialValue: nil)
        } else if otherEntry.receiptType == "pdf",
                  let data = otherEntry.receiptData {
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
            }
            ReceiptPickerSection(
                receiptImage: $receiptImage,
                pdfData: $pdfData,
                showingReceiptOptions: $showingReceiptOptions,
                receiptSource: $receiptSource,
                buttonLabel: "Beleg ändern",
                clearsOnSelect: true
            )
            ReceiptPreviewSection(
                receiptImage: receiptImage,
                pdfData: pdfData,
                showDetailAction: { showReceiptDetail = true }
            )
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
        .sheet(item: $receiptSource) { _ in
            ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
        }
        .sheet(isPresented: $showReceiptDetail) {
            NavigationView {
                ReceiptDetailView(receiptImage: receiptImage, pdfData: pdfData)
            }
        }
        .errorAlert(isPresented: $showErrorAlert, message: errorAlertMessage, showMailView: $showMailView)
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
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern EditOtherEntryView")
            errorAlertMessage = "Fehler beim Speichern: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func deleteEntry() {
        viewContext.delete(otherEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Löschen EditOtherEntryView")
            errorAlertMessage = "Fehler beim Löschen: \(error.localizedDescription)"
            showErrorAlert = true
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
