import SwiftUI
import UIKit
import CoreData
import PhotosUI
import CoreLocation

// Bitte keine lokale hideKeyboard()-Definition – die globale Version (in View+Keyboard.swift) wird verwendet.

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
    
    // Receipt options
    @State private var showingReceiptOptions = false
    @State private var showingPhotoPicker = false
    @State private var showingPDFPicker = false
    @State private var showingScanner = false

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
                        Button("Aus Fotos wählen") { showingPhotoPicker = true }
                        Button("Aus Dateien (PDF) wählen") { showingPDFPicker = true }
                        Button("Kamera Scannen") { showingScanner = true }
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
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerView { image in
                    if let img = image {
                        receiptImage = img
                        pdfData = nil
                    }
                }
            }
            .sheet(isPresented: $showingPDFPicker) {
                PDFDocumentPicker { url in
                    if let url = url, let data = try? Data(contentsOf: url) {
                        pdfData = data
                        receiptImage = nil
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                DocumentScannerView { images in
                    if !images.isEmpty {
                        if let pdf = PDFCreator.createPDF(from: images) {
                            pdfData = pdf
                            receiptImage = nil
                        }
                    }
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
        if let pdfData = pdfData {
            newEntry.receiptData = pdfData
            newEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            newEntry.receiptType = "image"
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
