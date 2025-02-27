import CoreData

func deleteAllTestData() {
    let context = PersistenceController.shared.container.viewContext
    let model = PersistenceController.shared.container.managedObjectModel

    for entity in model.entities {
        if let name = entity.name {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeObjectIDs
            
            do {
                let result = try context.execute(batchDelete) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
                }
                ErrorLogger.shared.log(message: "Alle Objekte in \(name) wurden gelöscht.")
            } catch {
                ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Löschen der Einträge in \(name)")
            }
        }
    }
}

func deleteEntity(named entityName: String, in context: NSManagedObjectContext) -> Bool {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
    let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    batchDelete.resultType = .resultTypeObjectIDs
    
    do {
        let result = try context.execute(batchDelete) as? NSBatchDeleteResult
        if let objectIDs = result?.result as? [NSManagedObjectID] {
            let changes = [NSDeletedObjectsKey: objectIDs]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        }
        ErrorLogger.shared.log(message: "Alle Objekte in \(entityName) wurden gelöscht.")
        return true
    } catch {
        ErrorLogger.shared.log(error: error, additionalInfo: "Fehler beim Löschen der Einträge in \(entityName)")
        return false
    }
}

// Batch update utility
func batchUpdate(entity: String,
                predicate: NSPredicate? = nil,
                updates: [String: Any],
                in context: NSManagedObjectContext) throws -> Int {
    let request = NSBatchUpdateRequest(entityName: entity)
    request.predicate = predicate
    request.propertiesToUpdate = updates
    request.resultType = .updatedObjectIDsResultType
    
    let result = try context.execute(request) as? NSBatchUpdateResult
    if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
        let changes = [NSUpdatedObjectIDsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        return objectIDs.count
    }
    
    return 0
}

// Optimized fetch with configurable result size
func optimizedFetch<T: NSManagedObject>(entityName: String,
                                       predicate: NSPredicate? = nil,
                                       sortDescriptors: [NSSortDescriptor]? = nil,
                                       fetchLimit: Int? = nil,
                                       context: NSManagedObjectContext) throws -> [T] {
    let request = NSFetchRequest<T>(entityName: entityName)
    request.predicate = predicate
    request.sortDescriptors = sortDescriptors
    
    if let limit = fetchLimit {
        request.fetchLimit = limit
    }
    
    // Enable batch fetching for large result sets
    request.returnsObjectsAsFaults = false
    
    return try context.fetch(request)
}
