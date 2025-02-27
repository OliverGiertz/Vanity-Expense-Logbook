import Foundation
import CoreData

extension ExpenseCategory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExpenseCategory> {
        return NSFetchRequest<ExpenseCategory>(entityName: "ExpenseCategory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
}

extension ExpenseCategory: Identifiable {
}
