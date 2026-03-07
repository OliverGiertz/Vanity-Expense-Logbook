import SwiftUI
import UIKit
import CoreData
import CoreLocation

struct FuelEntryForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager

    @State private var date = Date()
    @State private var fuelType: String = "Diesel"
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
    @State private var manualAddress: String = ""
    @State private var showLocationPicker: Bool = false

    @State private var showingReceiptOptions = false
    @State private var receiptSource: ReceiptSource? = nil

    @State private var showErrorAlert: Bool = false
    @State private var errorAlertMessage: String = ""
    @State private var showMailView: Bool = false

    @State private var isLoading: Bool = false
    @State private var saveLocation: Bool = true
    @State private var showSuccessToast: Bool = false
    @State private var successSubtitle: String = ""

    // Locale-Formatter (de_DE)
    private static let deDecimal2: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()
    private static let deInteger: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 0
        f.usesGroupingSeparator = true
        return f
    }()
    private static let deCurrency2: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Datum")) {
                    DatePicker("Datum", selection: $date, displayedComponents: .date)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                }
                Section(header: Text("Kraftstoffauswahl")) {
                    Picker("Kraftstoffart", selection: $fuelType) {
                        ForEach(FuelEntry.fuelTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .onChange(of: fuelType) { _, _ in
                        HapticFeedback.selectionChanged()
                    }
                }
                Section(header: Text("Fahrzeuginformationen")) {
                    TextField("Aktueller KM Stand", text: $currentKm)
                        .keyboardType(.numberPad)
                        .submitLabel(.done)
                        .onSubmit { KeyboardHelper.hideKeyboard() }
                        .onChange(of: currentKm) { _, _ in updateKmDifference() }
                    if let diff = kmDifference {
                        FormMetricRow(label: "Gefahrene Kilometer:", value: "\(diff) km")
                    }
                    if let consumption = consumptionPer100km {
                        FormMetricRow(label: "Verbrauch pro 100km:", value: String(format: "%.2f L", consumption))
                    }
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
                    TextField("Gesamtkosten", text: $totalCost).disabled(true)
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
                SaveSection(title: "Speichern", action: { isLoading = true; saveEntry() }, isLoading: isLoading)
            }
            .navigationTitle("Tankbeleg")
        }
        .locationPickerSheet(isPresented: $showLocationPicker, selectedCoordinate: $selectedLocation, selectedAddress: $manualAddress)
        .receiptPickerSheet(receiptSource: $receiptSource, receiptImage: $receiptImage, pdfData: $pdfData)
        .errorAlert(isPresented: $showErrorAlert, message: errorAlertMessage, showMailView: $showMailView)
        .toast(isPresented: $showSuccessToast, title: "Eintrag gespeichert", subtitle: successSubtitle, systemImage: "checkmark.circle.fill", duration: 2.4, alignment: .bottom)
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

        let fetchRequest: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
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
            ErrorLogger.shared.log(error: error, additionalInfo: "Error updating km difference in FuelEntryForm")
            kmDifference = nil
            consumptionPer100km = nil
        }
    }

    private func saveEntry() {
        errorMessage = nil
        let costText = totalCost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = Double(costText) else {
            HapticFeedback.error()
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
                ErrorLogger.shared.log(message: "Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet in FuelEntryForm")
            }
        } else {
            chosenLocation = CLLocation(latitude: 0, longitude: 0)
        }

        let newEntry = FuelEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.fuelType = fuelType
        newEntry.isDiesel = (fuelType == "Diesel")
        newEntry.isAdBlue = (fuelType == "AdBlue")
        newEntry.currentKm = Int64(currentKm.replacingOccurrences(of: ",", with: ".")) ?? 0
        newEntry.liters = Double(liters.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        newEntry.costPerLiter = Double(costPerLiter.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        newEntry.totalCost = costValue
        newEntry.latitude = chosenLocation.coordinate.latitude
        newEntry.longitude = chosenLocation.coordinate.longitude
        newEntry.address = saveLocation ? (!manualAddress.isEmpty ? manualAddress : locationManager.address) : ""

        if let pdf = pdfData {
            newEntry.receiptData = pdf
            newEntry.receiptType = "pdf"
        } else if let image = receiptImage {
            let compressedImage = image.compressedForStorage()
            newEntry.receiptData = compressedImage.jpegData(compressionQuality: 0.7)
            newEntry.receiptType = "image"
        }

        let fetchRequest: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchOffset = 1
        fetchRequest.fetchLimit = 1

        do {
            let previousEntries = try viewContext.fetch(fetchRequest)
            if let previous = previousEntries.first {
                let kmDiff = newEntry.currentKm - previous.currentKm
                kmDifference = kmDiff
                if kmDiff > 0 {
                    if let litersValue = Double(liters.replacingOccurrences(of: ",", with: ".")) {
                        consumptionPer100km = (litersValue / Double(kmDiff)) * 100
                    }
                }
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Error fetching previous fuel entry in FuelEntryForm")
        }

        do {
            try viewContext.save()
            ErrorLogger.shared.log(message: "Eintrag erfolgreich gespeichert in FuelEntryForm")
            HapticFeedback.success()

            let recentText: String? = {
                if let c = consumptionPer100km, let s = formatDecimal2(c) {
                    return "⌀ seit letztem: \(s) L/100 km"
                }
                return nil
            }()
            let overallAvg = calculateOverallAverageConsumption()
            let overallText: String? = {
                if let avg = overallAvg, let s = formatDecimal2(avg) { return "Gesamt: \(s) L/100 km" }
                return nil
            }()
            let costPer100Text: String? = createCostPer100Text(totalCost: costValue)
            let trendText: String? = calculateTrendText(recentConsumption: consumptionPer100km)
            let rangeTextOrHint: String? = calculateRangeText(usingOverall: overallAvg ?? consumptionPer100km)

            let parts = [recentText, overallText, trendText, costPer100Text, rangeTextOrHint]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            successSubtitle = parts.joined(separator: " • ")
            withAnimation { showSuccessToast = true }

            clearFields()
            isLoading = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Speichern in FuelEntryForm")
            HapticFeedback.error()
            errorAlertMessage = "Fehler beim Speichern: \(error.localizedDescription)"
            showErrorAlert = true
            isLoading = false
        }
    }

    private func calculateOverallAverageConsumption() -> Double? {
        let request: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
        request.predicate = NSPredicate(format: "isDiesel == %@", NSNumber(value: true))
        do {
            let entries = try viewContext.fetch(request)
            let sortedAsc = entries.sorted { $0.date < $1.date }
            guard sortedAsc.count >= 2,
                  let first = sortedAsc.first,
                  let last = sortedAsc.last,
                  last.currentKm > first.currentKm else { return nil }
            let totalKm = Double(last.currentKm - first.currentKm)
            let totalLiters = entries.reduce(0.0) { $0 + $1.liters }
            let avg = (totalLiters / totalKm) * 100
            return avg
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler bei Durchschnittsberechnung in FuelEntryForm")
            return nil
        }
    }

    private func calculateTrendText(recentConsumption: Double?) -> String? {
        guard let recent = recentConsumption else { return nil }
        let req: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
        req.predicate = NSPredicate(format: "isDiesel == %@", NSNumber(value: true))
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        req.fetchOffset = 1
        req.fetchLimit = 2
        do {
            let items = try viewContext.fetch(req)
            guard items.count == 2 else { return nil }
            let prev = items[0]
            let prevPrev = items[1]
            let kmDiff = prev.currentKm - prevPrev.currentKm
            guard kmDiff > 0 else { return nil }
            let prevConsumption = (prev.liters / Double(kmDiff)) * 100
            let delta = recent - prevConsumption
            let arrow: String
            if abs(delta) < 0.001 { arrow = "=" }
            else if delta < 0 { arrow = "↓" }
            else { arrow = "↑" }
            if let s = formatDecimal2(abs(delta)) { return "Trend: \(arrow) \(s) L/100 km" }
            return nil
        } catch {
            ErrorLogger.shared.log(error: error, additionalInfo: "Fehler bei Trendberechnung in FuelEntryForm")
            return nil
        }
    }

    private func calculateRangeText(usingOverall avgOrRecent: Double?) -> String? {
        let req: NSFetchRequest<VehicleProfile> = NSFetchRequest(entityName: "VehicleProfile")
        do {
            let profiles = try viewContext.fetch(req)
            guard let profile = profiles.first else { return nil }
            let tankVol = profile.tankVolume
            guard tankVol > 0 else { return "Profil: Tankvolumen pflegen" }
            guard let cons = avgOrRecent, cons > 0 else { return nil }
            let range = (tankVol / cons) * 100.0
            if let s = formatInteger(range) { return "Reichweite ~ \(s) km" }
            return nil
        } catch {
            return nil
        }
    }

    private func createCostPer100Text(totalCost: Double) -> String? {
        if let diff = kmDifference, diff > 0 {
            let costPer100 = (totalCost / Double(diff)) * 100.0
            if let costStr = formatCurrency2(costPer100) {
                return "Kosten: \(costStr)/100 km"
            }
        }
        return nil
    }

    // MARK: - Format Helpers (de_DE)
    private func formatDecimal2(_ value: Double) -> String? {
        FuelEntryForm.deDecimal2.string(from: NSNumber(value: value))
    }
    private func formatInteger(_ value: Double) -> String? {
        FuelEntryForm.deInteger.string(from: NSNumber(value: round(value)))
    }
    private func formatCurrency2(_ value: Double) -> String? {
        FuelEntryForm.deCurrency2.string(from: NSNumber(value: value))
    }

    private func clearFields() {
        date = Date()
        fuelType = "Diesel"
        currentKm = ""
        liters = ""
        costPerLiter = ""
        totalCost = "0,00"
        receiptImage = nil
        pdfData = nil
        selectedLocation = nil
        manualAddress = ""
    }
}

struct FuelEntryForm_Previews: PreviewProvider {
    static var previews: some View {
        FuelEntryForm()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
