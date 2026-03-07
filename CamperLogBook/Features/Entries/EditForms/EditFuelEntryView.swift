import SwiftUI
import CoreData
import CoreLocation

struct EditFuelEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var fuelEntry: FuelEntry

    @State private var date: Date
    @State private var fuelType: String
    @State private var currentKm: String
    @State private var liters: String
    @State private var costPerLiter: String
    @State private var totalCost: String
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    @State private var showReceiptDetail = false

    @State private var saveLocation: Bool
    @State private var manualLocation: CLLocationCoordinate2D?
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false

    init(fuelEntry: FuelEntry) {
        self.fuelEntry = fuelEntry
        _date = State(initialValue: fuelEntry.date)
        _fuelType = State(initialValue: FuelEntry.normalizedFuelType(fuelEntry.fuelType, isDiesel: fuelEntry.isDiesel, isAdBlue: fuelEntry.isAdBlue))
        _currentKm = State(initialValue: String(fuelEntry.currentKm))
        _liters = State(initialValue: String(fuelEntry.liters))
        _costPerLiter = State(initialValue: String(fuelEntry.costPerLiter))
        _totalCost = State(initialValue: String(fuelEntry.totalCost))
        if fuelEntry.receiptType == "image",
           let data = fuelEntry.receiptData,
           let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
            _pdfData = State(initialValue: nil)
        } else if fuelEntry.receiptType == "pdf",
                  let data = fuelEntry.receiptData {
            _receiptImage = State(initialValue: nil)
            _pdfData = State(initialValue: data)
        } else {
            _receiptImage = State(initialValue: nil)
            _pdfData = State(initialValue: nil)
        }
        _saveLocation = State(initialValue: fuelEntry.latitude != 0)
        if fuelEntry.latitude != 0 {
            _manualLocation = State(initialValue: CLLocationCoordinate2D(latitude: fuelEntry.latitude, longitude: fuelEntry.longitude))
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
            Section(header: Text("Kraftstoffauswahl")) {
                Picker("Kraftstoffart", selection: $fuelType) {
                    ForEach(FuelEntry.fuelTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .onChange(of: fuelType) { _, _ in
                    HapticFeedback.selectionChanged()
                }
            }
            Section(header: Text("Fahrzeuginformationen")) {
                TextField("Aktueller KM Stand", text: $currentKm)
                    .keyboardType(.numberPad)
            }
            Section(header: Text("Tankdaten")) {
                TextField("Getankte Liter", text: $liters)
                    .keyboardType(.decimalPad)
                TextField("Kosten pro Liter", text: $costPerLiter)
                    .keyboardType(.decimalPad)
                TextField("Gesamtkosten", text: $totalCost)
                    .disabled(true)
            }
            LocationSection(
                saveLocation: $saveLocation,
                manualAddress: manualAddress,
                locationManager: nil,
                manualLocation: manualLocation,
                address: fuelEntry.address,
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
            Button("Änderungen speichern") {
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
        .navigationTitle("Eintrag bearbeiten")
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
        guard let costValue = Double(costPerLiter.replacingOccurrences(of: ",", with: ".")),
              let currentKmValue = Int64(currentKm) else {
            HapticFeedback.error()
            return
        }
        fuelEntry.date = date
        fuelEntry.fuelType = fuelType
        fuelEntry.isDiesel = (fuelType == "Diesel")
        fuelEntry.isAdBlue = (fuelType == "AdBlue")
        fuelEntry.currentKm = currentKmValue
        fuelEntry.liters = Double(liters) ?? 0.0
        fuelEntry.costPerLiter = costValue
        let computedTotal = (Double(liters) ?? 0.0) * costValue
        fuelEntry.totalCost = computedTotal
        if let pdfData = pdfData {
            fuelEntry.receiptData = pdfData
            fuelEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            fuelEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            fuelEntry.receiptType = "image"
        }
        if saveLocation {
            if let loc = manualLocation {
                fuelEntry.latitude = loc.latitude
                fuelEntry.longitude = loc.longitude
            }
            if !manualAddress.isEmpty {
                fuelEntry.address = manualAddress
            }
        } else {
            fuelEntry.latitude = 0
            fuelEntry.longitude = 0
            fuelEntry.address = ""
        }
        do {
            try viewContext.save()
            HapticFeedback.success()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern EditFuelEntryView")
            HapticFeedback.error()
        }
    }

    private func deleteEntry() {
        HapticFeedback.impactMedium()
        viewContext.delete(fuelEntry)
        do {
            try viewContext.save()
            HapticFeedback.success()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Löschen EditFuelEntryView")
            HapticFeedback.error()
        }
    }
}

struct EditFuelEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let entry = FuelEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.fuelType = "Diesel"
        entry.isDiesel = true
        entry.isAdBlue = false
        entry.currentKm = 10000
        entry.liters = 50.0
        entry.costPerLiter = 1.5
        entry.totalCost = 75.0
        entry.address = "Musterstraße 1, 12345 Musterstadt"
        entry.receiptType = "image"
        entry.receiptData = UIImage(systemName: "fuelpump")?.jpegData(compressionQuality: 0.8)
        entry.latitude = 51.0
        entry.longitude = 7.0
        return NavigationView {
            EditFuelEntryView(fuelEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
