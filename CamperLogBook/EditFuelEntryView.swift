import SwiftUI
import CoreData
import PhotosUI

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

    init(fuelEntry: FuelEntry) {
        self.fuelEntry = fuelEntry
        _date = State(initialValue: fuelEntry.date)
        _isDiesel = State(initialValue: fuelEntry.isDiesel)
        _isAdBlue = State(initialValue: fuelEntry.isAdBlue)
        _currentKm = State(initialValue: String(fuelEntry.currentKm))
        _liters = State(initialValue: String(fuelEntry.liters))
        _costPerLiter = State(initialValue: String(fuelEntry.costPerLiter))
        _totalCost = State(initialValue: String(fuelEntry.totalCost))
        if let data = fuelEntry.receiptData, let image = UIImage(data: data) {
            _receiptImage = State(initialValue: image)
        } else {
            _receiptImage = State(initialValue: nil)
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Datum")) {
                DatePicker("Datum", selection: $date, displayedComponents: .date)
                    .submitLabel(.done)
            }
            Section(header: Text("Kraftstoffauswahl")) {
                // Beide Toggle aktiv – Diesel kann abgewählt werden
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
    }

    private func saveChanges() {
        guard let currentKmValue = Int64(currentKm),
              let litersValue = Double(liters),
              let costValue = Double(costPerLiter) else {
            return
        }
        let computedTotal = litersValue * costValue
        fuelEntry.date = date
        fuelEntry.isDiesel = isDiesel
        fuelEntry.isAdBlue = isAdBlue
        fuelEntry.currentKm = currentKmValue
        fuelEntry.liters = litersValue
        fuelEntry.costPerLiter = costValue
        fuelEntry.totalCost = computedTotal
        if let image = receiptImage {
            fuelEntry.receiptData = image.jpegData(compressionQuality: 0.8)
        }
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }

    private func deleteEntry() {
        viewContext.delete(fuelEntry)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Löschen: \(error)")
        }
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
        return NavigationView {
            EditFuelEntryView(fuelEntry: entry)
        }
        .environment(\.managedObjectContext, context)
    }
}
