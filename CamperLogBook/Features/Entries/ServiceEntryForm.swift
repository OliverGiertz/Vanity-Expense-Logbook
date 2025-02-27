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
    @State private var pdfData: Data? = nil  // Falls benötigt
    
    // Neuer State für Frischwasser-Eingabe
    @State private var freshWaterText: String = ""
    
    // Neue States für manuellen Standort
    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false
    
    // Zustände für Beleg-Auswahl
    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    
    // Fehlerhandling
    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showMailView: Bool = false

    // Toggle für Standort speichern (default: aktiv)
    @State private var saveLocation: Bool = true

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
                Section(header: Text("Standort")) {
                    Toggle("Standort speichern", isOn: $saveLocation)
                    if saveLocation {
                        if !manualAddress.isEmpty {
                            Text("Manuell ausgewählt: \(manualAddress)")
                        } else if let _ = locationManager.lastLocation {
                            Text("Automatisch ermittelt: \(locationManager.address)")
                        } else if let manualLocation = selectedLocation {
                            Text("Manuell ausgewählt: Lat: \(manualLocation.latitude), Lon: \(manualLocation.longitude)")
                        } else {
                            Text("Kein Standort ermittelt")
                        }
                        Button("Standort manuell auswählen") {
                            showLocationPicker = true
                        }
                    } else {
                        Text("Standort wird nicht gespeichert")
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
                    LocationPickerView(selectedCoordinate: $selectedLocation, selectedAddress: $manualAddress)
                }
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
            .sheet(item: $receiptSource) { source in
                ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
            }
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
        }
    }
    
    private func saveEntry() {
        let costText = cost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = Double(costText) else {
            ErrorLogger.shared.log(message: "Kostenkonvertierung fehlgeschlagen in ServiceEntryForm")
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
        }
        do {
            try viewContext.save()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern ServiceEntry in ServiceEntryForm")
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
