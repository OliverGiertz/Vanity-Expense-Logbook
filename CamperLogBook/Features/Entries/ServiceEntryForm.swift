import SwiftUI
import CoreData
import CoreLocation

struct ServiceEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var isSupply: Bool = false
    @State private var isDisposal: Bool = false
    @State private var cost: String = ""
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data? = nil

    @State private var freshWaterText: String = ""

    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil

    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showMailView: Bool = false

    @State private var saveLocation: Bool = true
    @State private var showSuccessToast: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datum")) {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                }
                Section(header: Text("Art der Leistung")) {
                    Toggle("Versorgung", isOn: $isSupply)
                        .onChange(of: isSupply) { _, _ in
                            HapticFeedback.selectionChanged()
                        }
                    Toggle("Entsorgung", isOn: $isDisposal)
                        .onChange(of: isDisposal) { _, _ in
                            HapticFeedback.selectionChanged()
                        }
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
                    locationManager: locationManager,
                    manualLocation: selectedLocation,
                    showPickerAction: { showLocationPicker = true }
                )
                ReceiptPickerSection(
                    receiptImage: $receiptImage,
                    pdfData: $pdfData,
                    showingReceiptOptions: $showingReceiptOptions,
                    receiptSource: $receiptSource
                )
                SaveSection(title: "Speichern", action: saveEntry)
            }
            .navigationTitle("Ver-/Entsorgung")
        }
        .locationPickerSheet(isPresented: $showLocationPicker, selectedCoordinate: $selectedLocation, selectedAddress: $manualAddress)
        .receiptPickerSheet(receiptSource: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
        .errorAlert(isPresented: $showErrorAlert, message: errorAlertMessage, showMailView: $showMailView)
        .toast(
            isPresented: $showSuccessToast,
            title: "Eintrag gespeichert",
            subtitle: nil,
            systemImage: "checkmark.circle.fill",
            duration: 2.0,
            alignment: .bottom
        )
    }

    private func saveEntry() {
        let costText = cost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = Double(costText) else {
            ErrorLogger.shared.log(message: "Kostenkonvertierung fehlgeschlagen in ServiceEntryForm")
            HapticFeedback.error()
            errorAlertMessage = "Kosten ungültig."
            showErrorAlert = true
            return
        }

        let chosenLocation: CLLocation
        if saveLocation {
            if let autoLocation = locationManager.lastLocation {
                chosenLocation = autoLocation
            } else if let manualLocation = selectedLocation {
                chosenLocation = CLLocation(latitude: manualLocation.latitude, longitude: manualLocation.longitude)
            } else {
                chosenLocation = CLLocation(latitude: 0, longitude: 0)
                ErrorLogger.shared.log(message: "Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet in ServiceEntryForm")
            }
        } else {
            chosenLocation = CLLocation(latitude: 0, longitude: 0)
        }
        let newEntry = ServiceEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.isSupply = isSupply
        newEntry.isDisposal = isDisposal
        newEntry.cost = costValue
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        newEntry.address = saveLocation ? (!manualAddress.isEmpty ? manualAddress : locationManager.address) : ""
        if isSupply {
            newEntry.freshWater = Double(freshWaterText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        } else {
            newEntry.freshWater = 0.0
        }
        if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
        } else if let pdf = pdfData {
            newEntry.receiptData = pdf
        }
        do {
            try viewContext.save()
            HapticFeedback.success()
            withAnimation { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern ServiceEntry in ServiceEntryForm")
            HapticFeedback.error()
            errorAlertMessage = "Fehler beim Speichern: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
}

struct ServiceEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        ServiceEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
