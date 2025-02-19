import SwiftUI
import CoreData

enum DebugEntity: String, CaseIterable, Identifiable {
    case fuel = "FuelEntry"
    case gas = "GasEntry"
    case service = "ServiceEntry"
    case other = "OtherEntry"
    
    var id: String { self.rawValue }
}

struct CoreDataDebugView: View {
    @State private var selectedEntity: DebugEntity = .fuel
    
    var body: some View {
        VStack {
            Picker("Tabelle auswählen", selection: $selectedEntity) {
                ForEach(DebugEntity.allCases) { entity in
                    Text(entity.rawValue).tag(entity)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Je nach Auswahl wird die entsprechende Liste angezeigt.
            switch selectedEntity {
            case .fuel:
                FuelEntryDebugList()
            case .gas:
                GasEntryDebugList()
            case .service:
                ServiceEntryDebugList()
            case .other:
                OtherEntryDebugList()
            }
        }
        .navigationTitle("Core Data Debug")
    }
}

struct FuelEntryDebugList: View {
    @FetchRequest(fetchRequest: FuelEntry.fetchAll()) var items: FetchedResults<FuelEntry>
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditFuelEntryView(fuelEntry: item)) {
                    VStack(alignment: .leading) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("KM: \(item.currentKm), TotalCost: \(item.totalCost)")
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

struct GasEntryDebugList: View {
    @FetchRequest(fetchRequest: GasEntry.fetchAll()) var items: FetchedResults<GasEntry>
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditGasEntryView(gasEntry: item)) {
                    VStack(alignment: .leading) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("CostPerBottle: \(item.costPerBottle), BottleCount: \(item.bottleCount)")
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

struct ServiceEntryDebugList: View {
    @FetchRequest(fetchRequest: ServiceEntry.fetchAll()) var items: FetchedResults<ServiceEntry>
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditServiceEntryView(serviceEntry: item)) {
                    VStack(alignment: .leading) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("Cost: \(item.cost)")
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

struct OtherEntryDebugList: View {
    @FetchRequest(fetchRequest: OtherEntry.fetchAll()) var items: FetchedResults<OtherEntry>
    
    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                NavigationLink(destination: EditOtherEntryView(otherEntry: item)) {
                    VStack(alignment: .leading) {
                        Text("Datum: \(item.date, formatter: debugDateFormatter)")
                        Text("Kategorie: \(item.category), Cost: \(item.cost)")
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

private let debugDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()
