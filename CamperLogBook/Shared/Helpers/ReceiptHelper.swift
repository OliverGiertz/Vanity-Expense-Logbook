import UIKit
import CoreData

/// Centralises receipt-saving logic that was previously duplicated across all 8 entry forms.
///
/// Uses KVC so it works with all NSManagedObject subclasses regardless of whether they
/// declare a `receiptType` attribute (ServiceEntry does not).
enum ReceiptHelper {

    /// Applies receipt data from a captured image or PDF to a Core Data entry.
    /// The image is resized and compressed before storage; PDF data is stored as-is.
    static func apply(image: UIImage?, pdfData: Data?, to entry: NSManagedObject) {
        if let pdf = pdfData {
            entry.setValue(pdf, forKey: "receiptData")
            setTypeIfSupported("pdf", on: entry)
        } else if let img = image {
            let data = img.compressedForStorage().jpegData(compressionQuality: 0.7)
            entry.setValue(data, forKey: "receiptData")
            setTypeIfSupported("image", on: entry)
        }
    }

    // MARK: - Private

    /// Only writes `receiptType` if the entity model declares that attribute.
    private static func setTypeIfSupported(_ type: String, on entry: NSManagedObject) {
        guard entry.entity.attributesByName["receiptType"] != nil else { return }
        entry.setValue(type, forKey: "receiptType")
    }
}
