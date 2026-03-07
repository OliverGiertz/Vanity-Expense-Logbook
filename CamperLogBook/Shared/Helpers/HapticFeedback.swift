import UIKit

enum HapticFeedback {
    static func success() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    static func error() {
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }

    static func impactMedium() {
        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    static func selectionChanged() {
        DispatchQueue.main.async {
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
}
