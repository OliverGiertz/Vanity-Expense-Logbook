import SwiftUI
import CoreData
import PhotosUI
import CoreLocation

struct ServiceEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager

    @State private var date = Date()
    @State private var isSupply: Bool = false
    @State private var isDisposal: Bool = false
    @State private var cost: String = ""
    @State private var receiptImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    
    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker: Bool = false
    
    // Neuer State für Frischwasser-Eingabe
    @State private var freshWaterText: String = ""
    
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
                Section(header: Text("Art der Leistung")) {
                    // Toggle-Label angepasst zu "Versorgung"
                    Toggle("Versorgung", isOn: $isSupply)
                    Toggle("Entsorgung", isOn: $isDisposal)
                }
                // Falls Versorgung ausgewählt, zeige zusätzlich das Frischwasser-Feld
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
                Section(header: Text("Standort")) {
                    if let autoLocation = locationManager.lastLocation {
                        Text("Automatisch ermittelt: Lat: \(autoLocation.coordinate.latitude), Lon: \(autoLocation.coordinate.longitude)")
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
                    }
                    PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                        Text("Beleg auswählen")
                    }
                    .onChange(of: photoPickerItem) { _, _ in
                        if let newItem = photoPickerItem {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    receiptImage = uiImage
                                }
                            }
                        }
                    }
                }
                Button("Speichern") {
                    saveEntry()
                }
            }
            .navigationTitle("Ver-/Entsorgung")
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    LocationPickerView(selectedCoordinate: $selectedLocation)
                }
            }
            // Fehleralert und Mail-Versand
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
            .sheet(isPresented: $showMailView) {
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
        let costText = cost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = Double(costText) else {
            ErrorLogger.shared.log(message: "Kostenkonvertierung fehlgeschlagen in ServiceEntryForm")
            return
        }
        
        let chosenLocation: CLLocation
        if let autoLocation = locationManager.lastLocation {
            chosenLocation = autoLocation
        } else if let manualLocation = selectedLocation {
            chosenLocation = CLLocation(latitude: manualLocation.latitude, longitude: manualLocation.longitude)
        } else {
            chosenLocation = CLLocation(latitude: 0, longitude: 0)
            ErrorLogger.shared.log(message: "Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet in ServiceEntryForm")
        }
        let newEntry = ServiceEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.isSupply = isSupply
        newEntry.isDisposal = isDisposal
        newEntry.cost = costValue
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        // Falls Versorgung ausgewählt, versuche den Frischwasserwert zu parsen, ansonsten 0.0
        if isSupply {
            newEntry.freshWater = Double(freshWaterText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        } else {
            newEntry.freshWater = 0.0
        }
        if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
        }
        do {
            try viewContext.save()
            clearFields()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern ServiceEntry in ServiceEntryForm")
            errorAlertMessage = "Fehler beim Speichern des Service-Eintrags: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func clearFields() {
        date = Date()
        isSupply = false
        isDisposal = false
        cost = ""
        receiptImage = nil
        photoPickerItem = nil
        selectedLocation = nil
        freshWaterText = ""
    }
}
