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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datum")) {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .submitLabel(.done)
                        .onSubmit { hideKeyboard() }
                }
                Section(header: Text("Art der Leistung")) {
                    Toggle("Ver-sorgung", isOn: $isSupply)
                    Toggle("Entsorgung", isOn: $isDisposal)
                }
                Section(header: Text("Kosten")) {
                    TextField("Kosten", text: $cost)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .onSubmit { hideKeyboard() }
                }
                Section(header: Text("Standort")) {
                    if let location = locationManager.lastLocation {
                        Text("Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)")
                    } else {
                        Text("Standort wird ermittelt...")
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
        }
    }
    
    private func saveEntry() {
        // Ersetze Komma durch Punkt für die Konvertierung, z. B. "1,50" -> "1.50"
        guard let costValue = Double(cost.replacingOccurrences(of: ",", with: ".")) else {
            print("Kostenkonvertierung fehlgeschlagen.")
            return
        }
        let chosenLocation: CLLocation
        if let autoLocation = locationManager.lastLocation {
            chosenLocation = autoLocation
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
        if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
        }
        do {
            try viewContext.save()
            print("ServiceEntry gespeichert.")
            clearFields()
        } catch {
            print("Fehler beim Speichern des Service-Eintrags: \(error)")
        }
    }
    
    private func clearFields() {
        date = Date()
        isSupply = false
        isDisposal = false
        cost = ""
        receiptImage = nil
        photoPickerItem = nil
    }
}

struct ServiceEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        ServiceEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
