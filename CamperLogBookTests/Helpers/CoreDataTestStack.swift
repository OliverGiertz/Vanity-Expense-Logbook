import CoreData
@testable import CamperLogBook

/// An in-memory CoreData stack for use in unit tests.
/// Each test should create its own instance to guarantee isolation.
struct CoreDataTestStack {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() {
        container = NSPersistentContainer(name: "CamperLogBook")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Test CoreData stack failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
