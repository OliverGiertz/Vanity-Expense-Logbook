import CoreData
@testable import CamperLogBook

/// An in-memory CoreData stack for use in unit tests.
/// Each test should create its own instance to guarantee isolation.
struct CoreDataTestStack {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() {
        container = NSPersistentContainer(name: "CamperLogBook")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        // Unique URL per instance ensures full store isolation during parallel test execution.
        // Without this, containers sharing the same name reuse the same in-memory store,
        // causing NSCocoaErrorDomain Code=134020 when a second test opens the shared store.
        description.url = URL(fileURLWithPath: "/dev/null/").appendingPathComponent(UUID().uuidString)
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Test CoreData stack failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
