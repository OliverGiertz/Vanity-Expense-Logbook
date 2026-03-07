import SwiftUI
import UIKit
import CoreData
import PhotosUI
import CoreLocation

struct GasEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var costPerBottle: String = ""
    @State private var bottleCount: String = ""
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?

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
            .navigationTitle("Gasbeleg")
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
        guard let cost = Double(costPerBottle.replacingOccurrences(of: ",", with: ".")),
              let count = Int64(bottleCount) else {
            ErrorLogger.shared.log(message: "Eingabe ungültig in GasEntryForm")
            HapticFeedback.error()
            errorAlertMessage = "Eingabe ungültig."
            showErrorAlert = true
            return
        }
        let chosenLocation: CLLocation
        if saveLocation {
            if let autoLocation = locationManager.lastLocation {
                chosenLocation = autoLocation
            } else if let manual = selectedLocation {
                chosenLocation = CLLocation(latitude: manual.latitude, longitude: manual.longitude)
            } else {
                chosenLocation = CLLocation(latitude: 0, longitude: 0)
                ErrorLogger.shared.log(message: "Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet in GasEntryForm")
            }
        } else {
            chosenLocation = CLLocation(latitude: 0, longitude: 0)
        }
        let newEntry = GasEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.costPerBottle = cost
        newEntry.bottleCount = count
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        newEntry.address = saveLocation ? (!manualAddress.isEmpty ? manualAddress : locationManager.address) : ""
        if let pdfData = pdfData {
            newEntry.receiptData = pdfData
            newEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            newEntry.receiptType = "image"
        }
        do {
            try viewContext.save()
            ErrorLogger.shared.log(message: "GasEntry erfolgreich gespeichert in GasEntryForm")
            HapticFeedback.success()
            clearFields()
            withAnimation { showSuccessToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern GasEntry in GasEntryForm")
            HapticFeedback.error()
            errorAlertMessage = "Fehler beim Speichern des GasEntry: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func clearFields() {
        date = Date()
        costPerBottle = ""
        bottleCount = ""
        receiptImage = nil
        pdfData = nil
        selectedLocation = nil
        manualAddress = ""
    }
}

struct GasEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        GasEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
