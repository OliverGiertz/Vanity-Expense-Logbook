import SwiftUI
import CoreData
import CoreLocation

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
    @State private var freshWaterText: String

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    @State private var showReceiptDetail = false

    @State private var saveLocation: Bool
    @State private var manualLocation: CLLocationCoordinate2D?
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false

    init(serviceEntry: ServiceEntry) {
        self.serviceEntry = serviceEntry
        _date = State(initialValue: serviceEntry.date)
        _isSupply = State(initialValue: serviceEntry.isSupply)
        _isDisposal = State(initialValue: serviceEntry.isDisposal)
        _cost = State(initialValue: String(serviceEntry.cost))
        _freshWaterText = State(initialValue: String(serviceEntry.freshWater))
        if let data = serviceEntry.receiptData, let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
            _pdfData = State(initialValue: nil)
        } else if let data = serviceEntry.receiptData {
            _receiptImage = State(initialValue: nil)
            _pdfData = State(initialValue: data)
        } else {
            _receiptImage = State(initialValue: nil)
            _pdfData = State(initialValue: nil)
        }
        _saveLocation = State(initialValue: serviceEntry.latitude != 0)
        if serviceEntry.latitude != 0 {
            _manualLocation = State(initialValue: CLLocationCoordinate2D(latitude: serviceEntry.latitude, longitude: serviceEntry.longitude))
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
            LocationSection(
                saveLocation: $saveLocation,
                manualAddress: manualAddress,
                locationManager: nil,
                manualLocation: manualLocation,
                address: serviceEntry.address,
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
        .navigationTitle("Ver-/Entsorgung bearbeiten")
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
        if let image = receiptImage {
            serviceEntry.receiptData = image.jpegData(compressionQuality: 0.8)
        } else if let pdf = pdfData {
            serviceEntry.receiptData = pdf
        }
        if saveLocation {
            if let loc = manualLocation {
                serviceEntry.latitude = loc.latitude
                serviceEntry.longitude = loc.longitude
            }
            if !manualAddress.isEmpty {
                serviceEntry.address = manualAddress
            }
        } else {
            serviceEntry.latitude = 0
            serviceEntry.longitude = 0
            serviceEntry.address = ""
        }
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern EditServiceEntryView")
        }
    }

    private func deleteEntry() {
        viewContext.delete(serviceEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Löschen EditServiceEntryView")
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
        entry.address = "Beispielweg 10, 98765 Beispielstadt"
        entry.receiptData = UIImage(systemName: "doc")?.jpegData(compressionQuality: 0.8)
        entry.latitude = 52.0
        entry.longitude = 13.0
        return NavigationView {
            EditServiceEntryView(serviceEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
