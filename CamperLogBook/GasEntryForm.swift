import SwiftUI
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
    @State private var photoPickerItem: PhotosPickerItem?
    
    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datum")) {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .submitLabel(.done)
                        .onSubmit { hideKeyboard() }
                }
                Section(header: Text("Gaskosten")) {
                    TextField("Kosten pro Flasche", text: $costPerBottle)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .onSubmit { hideKeyboard() }
                    TextField("Anzahl Flaschen", text: $bottleCount)
                        .keyboardType(.numberPad)
                        .submitLabel(.done)
                        .onSubmit { hideKeyboard() }
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
            .navigationTitle("Gasbeleg")
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    LocationPickerView(selectedCoordinate: $selectedLocation)
                }
            }
        }
    }
    
    private func saveEntry() {
        guard let cost = Double(costPerBottle.replacingOccurrences(of: ",", with: ".")),
              let count = Int64(bottleCount) else {
            print("Eingabe ungültig.")
            return
        }
        let chosenLocation: CLLocation
        if let autoLocation = locationManager.lastLocation {
            chosenLocation = autoLocation
        } else if let manualLocation = selectedLocation {
            chosenLocation = CLLocation(latitude: manualLocation.latitude, longitude: manualLocation.longitude)
        } else {
            chosenLocation = CLLocation(latitude: 0, longitude: 0)
            print("Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet")
        }
        
        let newEntry = GasEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.costPerBottle = cost
        newEntry.bottleCount = count
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
        }
        do {
            try viewContext.save()
            print("GasEntry gespeichert.")
            clearFields()
        } catch {
            print("Fehler beim Speichern des GasEntry: \(error)")
        }
    }
    
    private func clearFields() {
        date = Date()
        costPerBottle = ""
        bottleCount = ""
        receiptImage = nil
        photoPickerItem = nil
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
