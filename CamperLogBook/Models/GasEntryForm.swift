import SwiftUI
import UIKit
import CoreData
import PhotosUI
import CoreLocation

struct GasEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager

    @State private var date = Date()
    @State private var costPerBottle: String = ""
    @State private var bottleCount: String = ""
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?
    
    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker: Bool = false
    
    // DRY – einheitliche Zustände für die Beleg-Auswahl
    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    
    // Fehlerhandling States
    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showMailView: Bool = false

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
                Section(header: Text("Standort")) {
                    if let _ = locationManager.lastLocation {
                        Text("Automatisch ermittelt: \(locationManager.address)")
                    } else if let manualLocation = selectedLocation {
                        Text("Manuell ausgewählt: Lat: \(manualLocation.latitude), Lon: \(manualLocation.longitude)")
                    } else {
                        Text("Kein Standort ermittelt")
                        Button("Standort manuell auswählen") {
                            showLocationPicker = true
                        }
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
                    Button("Beleg auswählen") {
                        showingReceiptOptions = true
                    }
                    .confirmationDialog("Beleg Quelle wählen", isPresented: $showingReceiptOptions, titleVisibility: .visible) {
                        Button("Aus Fotos wählen") { receiptSource = .photo }
                        Button("Aus Dateien (PDF) wählen") { receiptSource = .pdf }
                        Button("Kamera Scannen") { receiptSource = .scanner }
                        Button("Abbrechen", role: .cancel) { }
                    }
                }
                Button("Speichern") {
                    saveEntry()
                }
            }
            .navigationTitle("Gasbeleg")
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    LocationPickerView(selectedCoordinate: $selectedLocation)
                }
            }
            .sheet(item: $receiptSource) { source in
                ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
            }
            // Fehleralert und Mailversand
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(errorAlertMessage),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .default(Text("Log senden"), action: {
                        showMailView = true
                    })
                )
            }
            .sheet(isPresented: $showMailView, onDismiss: {
                // Optional: Log zurücksetzen oder ähnliches
            }) {
                if let url = ErrorLogger.shared.getLogFileURL(),
                   let logData = try? Data(contentsOf: url) {
                    MailComposeView(
                        recipients: ["logfile@vanityontour.de"],
                        subject: "Fehlerlog",
                        messageBody: "Bitte prüfe den beigefügten Fehlerlog.",
                        attachmentData: logData,
                        attachmentMimeType: "text/plain",
                        attachmentFileName: "error.log"
                    )
                } else {
                    Text("Logdatei nicht verfügbar.")
                }
            }
        }
    }
    
    private func saveEntry() {
        guard let cost = Double(costPerBottle.replacingOccurrences(of: ",", with: ".")),
              let count = Int64(bottleCount) else {
            ErrorLogger.shared.log(message: "Eingabe ungültig in GasEntryForm")
            errorAlertMessage = "Eingabe ungültig."
            showErrorAlert = true
            return
        }
        let chosenLocation: CLLocation
        if let autoLocation = locationManager.lastLocation {
            chosenLocation = autoLocation
        } else if let manualLocation = selectedLocation {
            chosenLocation = CLLocation(latitude: manualLocation.latitude, longitude: manualLocation.longitude)
        } else {
            chosenLocation = CLLocation(latitude: 0, longitude: 0)
            ErrorLogger.shared.log(message: "Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet in GasEntryForm")
        }
        
        let newEntry = GasEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.costPerBottle = cost
        newEntry.bottleCount = count
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        // Adresse aus dem LocationManager übernehmen
        newEntry.address = locationManager.address
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
            clearFields()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern GasEntry in GasEntryForm")
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
    }
}

struct GasEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        GasEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
