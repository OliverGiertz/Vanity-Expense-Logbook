import CoreData

func deleteAllTestData() {
    let context = PersistenceController.shared.container.viewContext
    let model = PersistenceController.shared.container.managedObjectModel

    for entity in model.entities {
        if let name = entity.name {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
                print("Alle Objekte in \(name) wurden gelöscht.")
            } catch {
                print("Fehler beim Löschen der Einträge in \(name): \(error)")
            }
        }
    }
}

func deleteFaultyOtherEntry(in context: NSManagedObjectContext) {
    let faultyID = UUID(uuidString: "DF365B9D-5D5A-4C7C-BDFD-1C099A955968")!
    let request: NSFetchRequest<OtherEntry> = OtherEntry.fetchRequest() as! NSFetchRequest<OtherEntry>
    request.predicate = NSPredicate(format: "id == %@", faultyID as CVarArg)
    
    do {
        let entries = try context.fetch(request)
        for entry in entries {
            context.delete(entry)
        }
        try context.save()
        print("Fehlerhafter OtherEntry mit ID \(faultyID) wurde gelöscht.")
    } catch {
        print("Fehler beim Löschen des fehlerhaften OtherEntry: \(error)")
    }
}
