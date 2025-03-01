import Foundation
import StoreKit

/// Verwaltet Premium-Features und In-App-Käufe
class PremiumFeatureManager: ObservableObject {
    static let shared = PremiumFeatureManager()
    
    // Feature-IDs
    let backupFeatureID = "com.vanityontour.camperlogbook.icloudbackup"
    
    @Published var isBackupFeatureUnlocked = false
    @Published var purchaseInProgress = false
    @Published var lastErrorMessage: String?
    
    private init() {
        // In der Entwicklungs- und Debug-Umgebung freischalten
        #if DEBUG
        isBackupFeatureUnlocked = true
        print("📱 Debug-Modus: Premium-Features sind automatisch freigeschaltet!")
        #else
        loadPurchasedFeatures()
        #endif
    }
    
    /// Lädt bereits gekaufte Features
    private func loadPurchasedFeatures() {
        isBackupFeatureUnlocked = UserDefaults.standard.bool(forKey: backupFeatureID)
    }
    
    /// Speichert den Kauf eines Features
    private func savePurchasedFeature(id: String) {
        UserDefaults.standard.set(true, forKey: id)
        
        if id == backupFeatureID {
            DispatchQueue.main.async {
                self.isBackupFeatureUnlocked = true
            }
        }
    }
    
    /// Startet den Kaufprozess für ein Feature
    func purchaseFeature(id: String, completion: @escaping (Bool, String?) -> Void) {
        // In der DEBUG-Umgebung simulieren wir einen erfolgreichen Kauf
        #if DEBUG
        DispatchQueue.main.async {
            self.savePurchasedFeature(id: id)
            completion(true, nil)
        }
        return
        #endif
        
        self.purchaseInProgress = true
        
        // Im Produktionscode würde hier der tatsächliche In-App-Kauf erfolgen
        // 1. Produkt von Apple laden
        // 2. Kaufprozess starten
        // 3. Kaufbestätigung verarbeiten
        
        // Beispielhafte Implementierung mit SKProductsRequest:
        let request = SKProductsRequest(productIdentifiers: [id])
        request.delegate = SKProductRequestHandler.shared
        
        SKProductRequestHandler.shared.completionHandler = { products, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.purchaseInProgress = false
                    self.lastErrorMessage = "Fehler beim Laden der Produkte: \(error.localizedDescription)"
                    completion(false, self.lastErrorMessage)
                }
                return
            }
            
            guard let product = products?.first else {
                DispatchQueue.main.async {
                    self.purchaseInProgress = false
                    self.lastErrorMessage = "Produkt nicht gefunden"
                    completion(false, self.lastErrorMessage)
                }
                return
            }
            
            // Start purchase flow
            let payment = SKPayment(product: product)
            SKPaymentQueue.default().add(payment)
            
            // Kaufbestätigung würde normalerweise in SKPaymentTransactionObserver erfolgen
            // Hier simulieren wir einen erfolgreichen Kauf nach kurzer Verzögerung
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.purchaseInProgress = false
                self.savePurchasedFeature(id: id)
                completion(true, nil)
            }
        }
        
        request.start()
    }
    
    /// Prüft, ob ein Feature verfügbar ist
    func isFeatureAvailable(_ featureID: String) -> Bool {
        if featureID == backupFeatureID {
            return isBackupFeatureUnlocked
        }
        return false
    }
    
    /// Setzt alle gekauften Features zurück (für Testzwecke)
    func resetPurchases() {
        UserDefaults.standard.set(false, forKey: backupFeatureID)
        isBackupFeatureUnlocked = false
    }
}

// Helper-Klasse für SKProductsRequest
class SKProductRequestHandler: NSObject, SKProductsRequestDelegate {
    static let shared = SKProductRequestHandler()
    
    var completionHandler: (([SKProduct]?, Error?) -> Void)?
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        completionHandler?(products, nil)
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        completionHandler?(nil, error)
    }
}
