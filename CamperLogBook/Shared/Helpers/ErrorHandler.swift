import SwiftUI

struct ErrorHandler {
    /// Centralized error handling method
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - context: Description of where the error occurred
    ///   - alertMessage: Binding to the alert message string
    ///   - showAlert: Binding to the show alert boolean
    static func handle(_ error: Error, context: String, alertMessage: inout String, showAlert: inout Bool) {
        ErrorLogger.shared.log(error: error, additionalInfo: context)
        alertMessage = "Fehler: \(error.localizedDescription)"
        showAlert = true
    }
}

// Keyboard dismissal extension
extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                          to: nil, from: nil, for: nil)
        }
    }
}

// Loading state modifier
struct LoadingButton<Label: View>: View {
    var action: () async -> Void
    var isLoading: Bool
    @ViewBuilder var label: () -> Label
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            ZStack {
                label().opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                }
            }
        }
        .disabled(isLoading)
    }
}
