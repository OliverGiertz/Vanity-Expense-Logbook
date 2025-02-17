import SwiftUI
import CoreData

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()

struct OverviewView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: FuelEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: false)]
    ) var fuelEntries: FetchedResults<FuelEntry>

    @FetchRequest(
        entity: GasEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \GasEntry.date, ascending: false)]
    ) var gasEntries: FetchedResults<GasEntry>

    var body: some View {
        NavigationView {
            List {
                // Obere "unsichtbare" Tabelle
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
                            Text(String(format: "%.1f", daysPerBottle))
                                .bold()
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
                                Text("\(entry.date, formatter: dateFormatter)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let diff = fuelKmDifference(for: index, in: recentFuel) {
                                    let consumption = (entry.liters / Double(diff)) * 100
                                    Text("KM: \(diff), \(String(format: "%.2f L/100km", consumption))\nGesamtpreis: \(String(format: "%.2f €", entry.totalCost))")
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                } else {
                                    Text(String(format: "Gesamtpreis: %.2f €", entry.totalCost))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                    }
                }
                
                // Letzte 3 Gasbelege
                Section(header: Text("Letzte 3 Gasbelege")) {
                    ForEach(Array(gasEntries.prefix(3)), id: \.objectID) { entry in
                        NavigationLink(destination: EditGasEntryView(gasEntry: entry)) {
                            HStack {
                                Text("\(entry.date, formatter: dateFormatter)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                let total = entry.costPerBottle * Double(entry.bottleCount)
                                Text(String(format: "Gesamtpreis: %.2f €", total))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Übersicht")
            .listStyle(InsetGroupedListStyle())
        }
    }
    
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
    
    private func calculateDaysPerGasBottle() -> Double? {
        let sortedAsc = gasEntries.sorted { $0.date < $1.date }
        guard sortedAsc.count >= 2 else { return nil }
        let last = sortedAsc.last!
        let secondLast = sortedAsc[sortedAsc.count - 2]
        let daysDiff = Calendar.current.dateComponents([.day], from: secondLast.date, to: last.date).day ?? 0
        guard last.bottleCount > 0 else { return nil }
        return Double(daysDiff) / Double(last.bottleCount)
    }
    
    private func fuelKmDifference(for index: Int, in entries: [FuelEntry]) -> Int64? {
        if index < entries.count - 1 {
            let current = entries[index]
            let next = entries[index + 1]
            let diff = current.currentKm - next.currentKm
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
