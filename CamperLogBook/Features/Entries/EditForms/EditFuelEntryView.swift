//
//  EditFuelEntryView.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 16.02.25.
//

import SwiftUI
import CoreData
import PhotosUI
import CoreLocation

struct EditFuelEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var fuelEntry: FuelEntry

    @State private var date: Date
    @State private var isDiesel: Bool
    @State private var isAdBlue: Bool
    @State private var currentKm: String
    @State private var liters: String
    @State private var costPerLiter: String
    @State private var totalCost: String
    @State private var receiptImage: UIImage?
    @State private var pdfData: Data?
    
    // Zustände für die Beleg-Auswahl
    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil
    
    // Neuer State für die Belegvorschau
    @State private var showReceiptDetail = false
    
    // Neue States für den Standort in der Bearbeitung
    @State private var saveLocation: Bool
    @State private var manualLocation: CLLocationCoordinate2D?
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false

    init(fuelEntry: FuelEntry) {
        self.fuelEntry = fuelEntry
        _date = State(initialValue: fuelEntry.date)
        _isDiesel = State(initialValue: fuelEntry.isDiesel)
        _isAdBlue = State(initialValue: fuelEntry.isAdBlue)
        _currentKm = State(initialValue: String(fuelEntry.currentKm))
        _liters = State(initialValue: String(fuelEntry.liters))
        _costPerLiter = State(initialValue: String(fuelEntry.costPerLiter))
        _totalCost = State(initialValue: String(fuelEntry.totalCost))
        if fuelEntry.receiptType == "image",
           let data = fuelEntry.receiptData,
           let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
        } else if fuelEntry.receiptType == "pdf",
                  let data = fuelEntry.receiptData {
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
                    .onSubmit { hideKeyboard() }
            }
            Section(header: Text("Kraftstoffauswahl")) {
                Toggle("Diesel", isOn: $isDiesel)
                Toggle("AdBlue", isOn: $isAdBlue)
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
            Section(header: Text("Standort")) {
                Toggle("Standort speichern", isOn: $saveLocation)
                if saveLocation {
                    if !manualAddress.isEmpty {
                        Text("Manuell ausgewählt: \(manualAddress)")
                    } else if let loc = manualLocation {
                        Text("Manuell ausgewählt: Lat: \(loc.latitude), Lon: \(loc.longitude)")
                    } else if let address = fuelEntry.address, !address.isEmpty {
                        Text(address)
                    } else {
                        Text("Kein Standort ausgewählt")
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
                } else if pdfData != nil {
                    Image(systemName: "doc.richtext")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                }
                Button("Beleg ändern") {
                    // Alte Beleg-Daten löschen, um neue Auswahl zu ermöglichen
                    receiptImage = nil
                    pdfData = nil
                    showingReceiptOptions = true
                }
                .confirmationDialog("Beleg Quelle wählen", isPresented: $showingReceiptOptions, titleVisibility: .visible) {
                    Button("Aus Fotos wählen") { receiptSource = .photo }
                    Button("Aus Dateien (PDF) wählen") { receiptSource = .pdf }
                    Button("Kamera Scannen") { receiptSource = .scanner }
                    Button("Abbrechen", role: .cancel) { }
                }
            }
            if receiptImage != nil || pdfData != nil {
                Section(header: Text("Belegvorschau")) {
                    Button(action: { showReceiptDetail = true }) {
                        if let image = receiptImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                        } else if pdfData != nil {
                            Image(systemName: "doc.richtext")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                        }
                    }
                }
            }
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
        .sheet(item: $receiptSource) { source in
            ReceiptPickerSheet(source: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
        }
    }
    
    private func saveChanges() {
        guard let costValue = Double(costPerLiter.replacingOccurrences(of: ",", with: ".")),
              let currentKmValue = Int64(currentKm) else { return }
        fuelEntry.date = date
        fuelEntry.isDiesel = isDiesel
        fuelEntry.isAdBlue = isAdBlue
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
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Speichern EditFuelEntryView")
        }
    }
    
    private func deleteEntry() {
        viewContext.delete(fuelEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Löschen EditFuelEntryView")
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                          to: nil, from: nil, for: nil)
    }
}

struct EditFuelEntryView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let entry = FuelEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
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
