import SwiftUI
import CoreData
import CoreLocation

struct EditGasEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var gasEntry: GasEntry

    @State private var date: Date
    @State private var costPerBottle: String
    @State private var bottleCount: String
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    @State private var showReceiptDetail = false

    @State private var saveLocation: Bool
    @State private var manualLocation: CLLocationCoordinate2D?
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false

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
        _saveLocation = State(initialValue: gasEntry.latitude != 0)
        if gasEntry.latitude != 0 {
            _manualLocation = State(initialValue: CLLocationCoordinate2D(latitude: gasEntry.latitude, longitude: gasEntry.longitude))
        } else {
            _manualLocation = State(initialValue: nil)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Datum")) {
                DatePicker("Datum", selection: $date, displayedComponents: .date)
                    .submitLabel(.done)
                    .onSubmit { KeyboardHelper.hideKeyboard() }
            }
            Section(header: Text("Gaskosten")) {
                TextField("Kosten pro Flasche", text: $costPerBottle)
                    .keyboardType(.decimalPad)
                    .submitLabel(.done)
                    .onSubmit { KeyboardHelper.hideKeyboard() }
                TextField("Anzahl Flaschen", text: $bottleCount)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .onSubmit { KeyboardHelper.hideKeyboard() }
            }
            LocationSection(
                saveLocation: $saveLocation,
                manualAddress: manualAddress,
                locationManager: nil,
                manualLocation: manualLocation,
                address: gasEntry.address,
                showPickerAction: { showLocationPicker = true }
            )
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
        .navigationTitle("Gasbeleg bearbeiten")
        .sheet(isPresented: $showLocationPicker) {
            NavigationView {
                LocationPickerView(selectedCoordinate: $manualLocation, selectedAddress: $manualAddress)
            }
        }
        .sheet(item: $receiptSource) { _ in
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
        if let pdfData = pdfData {
            gasEntry.receiptData = pdfData
            gasEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            gasEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            gasEntry.receiptType = "image"
        }
        if saveLocation {
            if let loc = manualLocation {
                gasEntry.latitude = loc.latitude
                gasEntry.longitude = loc.longitude
            }
            if !manualAddress.isEmpty {
                gasEntry.address = manualAddress
            }
        } else {
            gasEntry.latitude = 0
            gasEntry.longitude = 0
            gasEntry.address = ""
        }
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern EditGasEntryView")
        }
    }

    private func deleteEntry() {
        viewContext.delete(gasEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Löschen EditGasEntryView")
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
        entry.address = "Beispielstraße 5, 54321 Beispielstadt"
        entry.receiptType = "image"
        entry.receiptData = UIImage(systemName: "gas")?.jpegData(compressionQuality: 0.8)
        entry.latitude = 50.0
        entry.longitude = 8.0
        return NavigationView {
            EditGasEntryView(gasEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
