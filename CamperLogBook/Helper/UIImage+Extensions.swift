import UIKit

extension UIImage {
    /// Resizes the image to the specified size
    /// - Parameter size: The target size
    /// - Returns: A resized UIImage
    func resized(to size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Compresses the image to a reasonable size for storage
    /// - Returns: A compressed UIImage
    func compressedForStorage() -> UIImage {
        let maxDimension: CGFloat = 1200
        let aspectRatio = size.width / size.height
        
        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: min(size.width, maxDimension), height: min(size.width, maxDimension) / aspectRatio)
        } else {
            newSize = CGSize(width: min(size.height, maxDimension) * aspectRatio, height: min(size.height, maxDimension))
        }
        
        return resized(to: newSize)
    }
}
