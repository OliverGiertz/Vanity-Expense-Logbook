import SwiftUI
import CoreData

struct DebugView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // NumberFormatter, der immer einen Punkt als Dezimaltrenner verwendet (en_US_POSIX)
    private var gpsFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 6
        formatter.maximumFractionDigits = 6
        return formatter
    }

    @FetchRequest(
        entity: FuelEntry.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "latitude != 0 AND longitude != 0")
    ) var fuelEntriesWithGPS: FetchedResults<FuelEntry>
    
    @FetchRequest(
        entity: GasEntry.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "latitude != 0 AND longitude != 0")
    ) var gasEntriesWithGPS: FetchedResults<GasEntry>
    
    @FetchRequest(
        entity: ServiceEntry.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "latitude != 0 AND longitude != 0")
    ) var serviceEntriesWithGPS: FetchedResults<ServiceEntry>
    
    @FetchRequest(
        entity: OtherEntry.entity(),
        sortDescriptors: [],
        predicate: NSPredicate(format: "latitude != 0 AND longitude != 0")
    ) var otherEntriesWithGPS: FetchedResults<OtherEntry>
    
    var totalGPSEntries: Int {
        fuelEntriesWithGPS.count +
        gasEntriesWithGPS.count +
        serviceEntriesWithGPS.count +
        otherEntriesWithGPS.count
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Aktionen")) {
                    Button(action: {
                        deleteAllTestData()
                    }) {
                        Text("Alle Testdaten löschen")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                
                Section(header: Text("Einträge einzelner Tabellen löschen")) {
                    Button("FuelEntry löschen") {
                        deleteAllEntries(entityName: "FuelEntry")
                    }
                    .foregroundColor(.red)
                    
                    Button("GasEntry löschen") {
                        deleteAllEntries(entityName: "GasEntry")
                    }
                    .foregroundColor(.red)
                    
                    Button("ServiceEntry löschen") {
                        deleteAllEntries(entityName: "ServiceEntry")
                    }
                    .foregroundColor(.red)
                    
                    Button("OtherEntry löschen") {
                        deleteAllEntries(entityName: "OtherEntry")
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("GPS Einträge")) {
                    Text("FuelEntry: \(fuelEntriesWithGPS.count)")
                    Text("GasEntry: \(gasEntriesWithGPS.count)")
                    Text("ServiceEntry: \(serviceEntriesWithGPS.count)")
                    Text("OtherEntry: \(otherEntriesWithGPS.count)")
                    Text("Gesamt: \(totalGPSEntries)")
                }
                
                Section(header: Text("Core Data Debug")) {
                    NavigationLink(destination: CoreDataDebugView(gpsFormatter: gpsFormatter)) {
                        Text("Core Data Einträge anzeigen")
                    }
                }
            }
            .navigationTitle("Debug")
        }
    }
    
    private func deleteAllEntries(entityName: String) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
        } catch {
            print("Fehler beim Löschen der Einträge in \(entityName): \(error)")
        }
    }
    
    private func deleteAllTestData() {
        let model = PersistenceController.shared.container.managedObjectModel
        for entity in model.entities {
            if let name = entity.name {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                deleteRequest.resultType = .resultTypeObjectIDs
                do {
                    let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
                    if let objectIDs = result?.result as? [NSManagedObjectID] {
                        let changes = [NSDeletedObjectsKey: objectIDs]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
                    }
                    print("Alle Objekte in \(name) wurden gelöscht.")
                } catch {
                    print("Fehler beim Löschen der Einträge in \(name): \(error)")
                }
            }
        }
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView()
    }
}
