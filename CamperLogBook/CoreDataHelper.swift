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
