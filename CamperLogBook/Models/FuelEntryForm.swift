import SwiftUI
import UIKit
import CoreData
import PhotosUI
import CoreLocation

struct FuelEntryForm: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var date = Date()
    @State private var isDiesel: Bool = true
    @State private var isAdBlue: Bool = false
    @State private var currentKm: String = ""
    @State private var liters: String = ""
    @State private var costPerLiter: String = ""
    @State private var totalCost: String = "0,00"
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?
    
    @State private var kmDifference: Int64?
    @State private var consumptionPer100km: Double?
    
    @State private var errorMessage: String?
    
    @State private var selectedLocation: CLLocationCoordinate2D? = nil
    @State private var showLocationPicker: Bool = false
    
    // DRY – einheitliche Zustände für die Beleg-Auswahl
    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datum")) {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                }
                Section(header: Text("Kraftstoffauswahl")) {
                    Toggle("Diesel", isOn: $isDiesel)
                    Toggle("AdBlue", isOn: $isAdBlue)
                }
                Section(header: Text("Fahrzeuginformationen")) {
                    TextField("Aktueller KM Stand", text: $currentKm)
                        .keyboardType(.numberPad)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                        .onChange(of: currentKm) { _, _ in updateKmDifference() }
                }
                Section(header: Text("Tankdaten")) {
                    TextField("Getankte Liter", text: $liters)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                        .onChange(of: liters) { _, _ in computeTotalCost() }
                    TextField("Kosten pro Liter", text: $costPerLiter)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                        .onChange(of: costPerLiter) { _, _ in computeTotalCost() }
                    TextField("Gesamtkosten", text: $totalCost)
                        .disabled(true)
                }
                Section(header: Text("Standort")) {
                    if let autoLocation = locationManager.lastLocation {
                        Text("Automatisch ermittelt: Lat: \(autoLocation.coordinate.latitude), Lon: \(autoLocation.coordinate.longitude)")
                    } else if let manualLocation = selectedLocation {
                        Text("Manuell ausgewählt: Lat: \(manualLocation.latitude), Lon: \(manualLocation.longitude)")
                    } else {
                        Text("Kein Standort ermittelt")
                        Button("Standort manuell auswählen") { showLocationPicker = true }
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
                if let kmDiff = kmDifference, let consumption = consumptionPer100km {
                    Section(header: Text("Zusätzliche Infos")) {
                        Text("Gefahrene KM seit letztem Tanken: \(kmDiff)")
                        Text(String(format: "Durchschnittsverbrauch: %.2f L/100 km", consumption))
                    }
                }
                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
                Button("Speichern") { saveEntry() }
            }
            .navigationTitle("Tankbeleg")
            .sheet(isPresented: $showLocationPicker) {
                NavigationView { LocationPickerView(selectedCoordinate: $selectedLocation) }
            }
            .sheet(item: $receiptSource) { source in
                ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
            }
        }
    }
    
    private func computeTotalCost() {
        if let litersValue = Double(liters.replacingOccurrences(of: ",", with: ".")),
           let costValue = Double(costPerLiter.replacingOccurrences(of: ",", with: ".")) {
            let computed = litersValue * costValue
            totalCost = String(format: "%.2f", computed).replacingOccurrences(of: ".", with: ",")
        } else {
            totalCost = "0,00"
        }
    }
    
    private func updateKmDifference() {
        guard let currentKmValue = Int64(currentKm.replacingOccurrences(of: ",", with: ".")) else {
            kmDifference = nil
            consumptionPer100km = nil
            return
        }
        let fetchRequest = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        do {
            let previousEntries = try viewContext.fetch(fetchRequest)
            if let previous = previousEntries.first {
                let diff = currentKmValue - previous.currentKm
                kmDifference = diff > 0 ? diff : nil
                if let litersValue = Double(liters.replacingOccurrences(of: ",", with: ".")), diff > 0 {
                    consumptionPer100km = (litersValue / Double(diff)) * 100
                } else {
                    consumptionPer100km = nil
                }
            } else {
                kmDifference = nil
                consumptionPer100km = nil
            }
        } catch {
            print("Error updating km difference: \(error)")
            kmDifference = nil
            consumptionPer100km = nil
        }
    }
    
    private func saveEntry() {
        errorMessage = nil
        guard let currentKmValue = Int64(currentKm.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ungültiger KM-Stand: \(currentKm)"
            print(errorMessage!)
            return
        }
        guard let litersValue = Double(liters.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ungültige Literzahl: \(liters)"
            print(errorMessage!)
            return
        }
        guard let costPerLiterValue = Double(costPerLiter.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ungültiger Preis pro Liter: \(costPerLiter)"
            print(errorMessage!)
            return
        }
        guard let totalCostValue = Double(totalCost.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Ungültige Gesamtkosten: \(totalCost)"
            print(errorMessage!)
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
        let newEntry = FuelEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.isDiesel = isDiesel
        newEntry.isAdBlue = isAdBlue
        newEntry.currentKm = currentKmValue
        newEntry.liters = litersValue
        newEntry.costPerLiter = costPerLiterValue
        newEntry.totalCost = totalCostValue
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        if let pdfData = pdfData {
            newEntry.receiptData = pdfData
            newEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            newEntry.receiptData = image.jpegData(compressionQuality: 0.8)
            newEntry.receiptType = "image"
        }
        let fetchRequest = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchOffset = 1
        fetchRequest.fetchLimit = 1
        do {
            let previousEntries = try viewContext.fetch(fetchRequest)
            if let previous = previousEntries.first {
                let kmDiff = newEntry.currentKm - previous.currentKm
                kmDifference = kmDiff
                if kmDiff > 0 {
                    consumptionPer100km = (litersValue / Double(kmDiff)) * 100
                }
            }
        } catch {
            print("Error fetching previous fuel entry: \(error)")
        }
        do {
            try viewContext.save()
            print("Eintrag erfolgreich gespeichert.")
            clearFields()
        } catch {
            errorMessage = "Fehler beim Speichern: \(error.localizedDescription)"
            print(errorMessage!)
        }
    }
    
    private func clearFields() {
        date = Date()
        isAdBlue = false
        currentKm = ""
        liters = ""
        costPerLiter = ""
        totalCost = "0,00"
        receiptImage = nil
        pdfData = nil
        selectedLocation = nil
    }
}

struct FuelEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        FuelEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
