import SwiftUI
import CoreData

// MARK: - DebugEntity Enum

enum DebugEntity: String, CaseIterable, Identifiable {
    case fuel = "FuelEntry"
    case gas = "GasEntry"
    case service = "ServiceEntry"
    case other = "OtherEntry"
    
    var id: String { self.rawValue }
}

// MARK: - Date Formatter

private let debugDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

// MARK: - FuelEntry Debug List

struct FuelEntryDebugList: View {
    @FetchRequest(fetchRequest: FuelEntry.fetchAll()) var items: FetchedResults<FuelEntry>
    var gpsFormatter: NumberFormatter
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditFuelEntryView(fuelEntry: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("KM: \(item.currentKm), TotalCost: \(item.totalCost)")
                        Text("GPS: Lat: \(gpsFormatter.string(from: NSNumber(value: item.latitude)) ?? "\(item.latitude)") , Lon: \(gpsFormatter.string(from: NSNumber(value: item.longitude)) ?? "\(item.longitude)")")
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let context = PersistenceController.shared.container.viewContext
        offsets.map { items[$0] }.forEach { context.delete($0) }
        do {
            try context.save()
        } catch {
            print("Error deleting FuelEntry: \(error)")
        }
    }
}

// MARK: - GasEntry Debug List

struct GasEntryDebugList: View {
    @FetchRequest(fetchRequest: GasEntry.fetchAll()) var items: FetchedResults<GasEntry>
    var gpsFormatter: NumberFormatter
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditGasEntryView(gasEntry: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("CostPerBottle: \(item.costPerBottle), BottleCount: \(item.bottleCount)")
                        Text("GPS: Lat: \(gpsFormatter.string(from: NSNumber(value: item.latitude)) ?? "\(item.latitude)") , Lon: \(gpsFormatter.string(from: NSNumber(value: item.longitude)) ?? "\(item.longitude)")")
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let context = PersistenceController.shared.container.viewContext
        offsets.map { items[$0] }.forEach { context.delete($0) }
        do {
            try context.save()
        } catch {
            print("Error deleting GasEntry: \(error)")
        }
    }
}

// MARK: - ServiceEntry Debug List

struct ServiceEntryDebugList: View {
    @FetchRequest(fetchRequest: ServiceEntry.fetchAll()) var items: FetchedResults<ServiceEntry>
    var gpsFormatter: NumberFormatter
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditServiceEntryView(serviceEntry: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("Cost: \(item.cost)")
                        Text("GPS: Lat: \(gpsFormatter.string(from: NSNumber(value: item.latitude)) ?? "\(item.latitude)") , Lon: \(gpsFormatter.string(from: NSNumber(value: item.longitude)) ?? "\(item.longitude)")")
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let context = PersistenceController.shared.container.viewContext
        offsets.map { items[$0] }.forEach { context.delete($0) }
        do {
            try context.save()
        } catch {
            print("Error deleting ServiceEntry: \(error)")
        }
    }
}

// MARK: - OtherEntry Debug List

struct OtherEntryDebugList: View {
    @FetchRequest(fetchRequest: OtherEntry.fetchAll()) var items: FetchedResults<OtherEntry>
    var gpsFormatter: NumberFormatter
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditOtherEntryView(otherEntry: item)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("Kategorie: \(item.category), Cost: \(item.cost)")
                        Text("GPS: Lat: \(gpsFormatter.string(from: NSNumber(value: item.latitude)) ?? "\(item.latitude)") , Lon: \(gpsFormatter.string(from: NSNumber(value: item.longitude)) ?? "\(item.longitude)")")
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        let context = PersistenceController.shared.container.viewContext
        offsets.map { items[$0] }.forEach { context.delete($0) }
        do {
            try context.save()
        } catch {
            print("Error deleting OtherEntry: \(error)")
        }
    }
}

// MARK: - CoreDataDebugView

struct CoreDataDebugView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedEntity: DebugEntity = .fuel
    var gpsFormatter: NumberFormatter
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("Tabelle auswählen", selection: $selectedEntity) {
                    ForEach(DebugEntity.allCases) { entity in
                        Text(entity.rawValue).tag(entity)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                switch selectedEntity {
                case .fuel:
                    FuelEntryDebugList(gpsFormatter: gpsFormatter)
                case .gas:
                    GasEntryDebugList(gpsFormatter: gpsFormatter)
                case .service:
                    ServiceEntryDebugList(gpsFormatter: gpsFormatter)
                case .other:
                    OtherEntryDebugList(gpsFormatter: gpsFormatter)
                }
            }
            .navigationTitle("Core Data Debug")
        }
    }
}

struct CoreDataDebugView_Previews: PreviewProvider {
    static var previews: some View {
        CoreDataDebugView(gpsFormatter: {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 6
            formatter.maximumFractionDigits = 6
            return formatter
        }())
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
