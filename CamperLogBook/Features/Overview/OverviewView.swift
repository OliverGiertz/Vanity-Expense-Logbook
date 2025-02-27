import SwiftUI
import CoreData

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()

struct OverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Nur echte Tankbelege (isDiesel == true)
    @FetchRequest(
        entity: FuelEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: false)],
        predicate: NSPredicate(format: "isDiesel == %@", NSNumber(value: true))
    ) var fuelEntries: FetchedResults<FuelEntry>
    
    @FetchRequest(
        entity: GasEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GasEntry.date, ascending: false)]
    ) var gasEntries: FetchedResults<GasEntry>

    var body: some View {
        NavigationView {
            List {
                // Obere Zusammenfassung
                VStack(spacing: 8) {
                    HStack {
                        Text("Verbrauch / 100 km")
                        Spacer()
                        if let consumption = calculateAverageConsumption() {
                            Text(String(format: "%.2f L/100km", consumption))
                                .bold()
                        } else {
                            Text("Nicht genügend Daten")
                                .bold()
                        }
                    }
                    HStack {
                        Text("Tage pro Gasflasche")
                        Spacer()
                        if let daysPerBottle = calculateDaysPerGasBottle() {
                            if let forecast = forecastDateForGasBottle() {
                                Text(String(format: "%.1f (~%@)", daysPerBottle, forecast))
                                    .bold()
                            } else {
                                Text(String(format: "%.1f", daysPerBottle))
                                    .bold()
                            }
                        } else {
                            Text("Nicht genügend Daten")
                                .bold()
                        }
                    }
                }
                .padding(.vertical, 4)
                
                // Letzte 3 Tankbelege
                Section(header: Text("Letzte 3 Tankbelege")) {
                    let recentFuel = Array(fuelEntries.prefix(3))
                    ForEach(0..<recentFuel.count, id: \.self) { index in
                        let entry = recentFuel[index]
                        NavigationLink(destination: EditFuelEntryView(fuelEntry: entry)) {
                            HStack {
                                // Linke Seite: Datum
                                Text("\(entry.date, formatter: dateFormatter)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Rechte Seite: Drei Zeilen in einem VStack
                                VStack(alignment: .trailing, spacing: 4) {
                                    if let diff = fuelKmDifference(for: index, in: recentFuel) {
                                        Text("\(diff) km")
                                    } else {
                                        Text("- km")
                                    }
                                    if let diff = fuelKmDifference(for: index, in: recentFuel), diff > 0 {
                                        let consumption = (entry.liters / Double(diff)) * 100
                                        Text("⌀ \(String(format: "%.2f", consumption)) L/100km")
                                    } else {
                                        Text("⌀ - L/100km")
                                    }
                                    Text(String(format: "%.2f €", entry.totalCost))
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
                
                // Letzte 3 Gasbelege
                Section(header: Text("Letzte 3 Gasbelege")) {
                    ForEach(Array(gasEntries.prefix(3)), id: \.objectID) { entry in
                        NavigationLink(destination: EditGasEntryView(gasEntry: entry)) {
                            HStack {
                                // Linke Seite: Datum
                                Text("\(entry.date, formatter: dateFormatter)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                let bottleCount = entry.bottleCount
                                let pricePerBottle = entry.costPerBottle
                                let total = pricePerBottle * Double(bottleCount)
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(bottleCount) x \(String(format: "%.2f", pricePerBottle))€")
                                    Text("= \(String(format: "%.2f", total))€")
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .refreshable {
                reloadData()
            }
            .navigationTitle("Übersicht")
            .listStyle(InsetGroupedListStyle())
        }
    }
    
    // Wird beim Pull-to-Refresh aufgerufen.
    private func reloadData() {
        viewContext.refreshAllObjects()
    }
    
    // Durchschnittsverbrauch aus allen Tankbelegen berechnen.
    private func calculateAverageConsumption() -> Double? {
        let sortedAsc = fuelEntries.sorted { $0.date < $1.date }
        guard sortedAsc.count >= 2,
              let first = sortedAsc.first,
              let last = sortedAsc.last,
              last.currentKm > first.currentKm else {
            return nil
        }
        let totalKm = Double(last.currentKm - first.currentKm)
        let totalLiters = fuelEntries.reduce(0.0) { $0 + $1.liters }
        return (totalLiters / totalKm) * 100
    }
    
    // Berechnet die Tage pro Gasflasche anhand der letzten zwei Gasbelege.
    private func calculateDaysPerGasBottle() -> Double? {
        let sortedAsc = gasEntries.sorted { $0.date < $1.date }
        guard sortedAsc.count >= 2 else { return nil }
        let last = sortedAsc.last!
        let secondLast = sortedAsc[sortedAsc.count - 2]
        let daysDiff = Calendar.current.dateComponents([.day], from: secondLast.date, to: last.date).day ?? 0
        guard last.bottleCount > 0 else { return nil }
        return Double(daysDiff) / Double(last.bottleCount)
    }
    
    // Berechnet ein voraussichtliches Datum: Letztes Gasbelegdatum plus aufgerundete durchschnittliche Tage.
    private func forecastDateForGasBottle() -> String? {
        let sortedAsc = gasEntries.sorted { $0.date < $1.date }
        guard sortedAsc.count >= 2,
              let last = sortedAsc.last,
              let daysPerBottle = calculateDaysPerGasBottle() else { return nil }
        let forecastDays = Int(ceil(daysPerBottle))
        if let forecastDate = Calendar.current.date(byAdding: .day, value: forecastDays, to: last.date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy"
            return formatter.string(from: forecastDate)
        }
        return nil
    }
    
    // Berechnet die gefahrenen Kilometer für einen Tankbeleg.
    // Für Einträge, bei denen ein nachfolgender Eintrag vorhanden ist, wird dieser verwendet.
    // Falls es sich um den letzten Eintrag handelt, wird der unmittelbar neuere (vorherige) Eintrag genutzt.
    private func fuelKmDifference(for index: Int, in entries: [FuelEntry]) -> Int64? {
        if index < entries.count - 1 {
            let current = entries[index]
            let next = entries[index + 1]
            let diff = current.currentKm - next.currentKm
            return diff > 0 ? diff : nil
        } else if index > 0 {
            let current = entries[index]
            let previous = entries[index - 1]
            let diff = previous.currentKm - current.currentKm
            return diff > 0 ? diff : nil
        }
        return nil
    }
}

struct OverviewView_Previews: PreviewProvider {
    static var previews: some View {
        OverviewView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
