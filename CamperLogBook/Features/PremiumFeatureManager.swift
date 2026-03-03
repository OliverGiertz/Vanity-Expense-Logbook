import Foundation
import StoreKit

@available(iOS 15.0, *)
@MainActor
class PremiumFeatureManager: ObservableObject {
    static let shared = PremiumFeatureManager()
    
    let backupFeatureID = "com.vanityontour.camperlogbook.icloudbackup"
    
    @Published var isBackupFeatureUnlocked = false
    @Published var purchaseInProgress = false
    @Published var lastErrorMessage: String?
    
    private var updatesTask: Task<Void, Never>?
    
    private init() {
        #if DEBUG
        isBackupFeatureUnlocked = true
        print("📱 Debug-Modus: Premium-Features sind automatisch freigeschaltet!")
        #else
        loadPurchasedFeatures()
        #endif
        
        updatesTask = Task {
            await observeTransactions()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    private func loadPurchasedFeatures() {
        isBackupFeatureUnlocked = UserDefaults.standard.bool(forKey: backupFeatureID)
    }
    
    private func savePurchasedFeature(id: String) {
        UserDefaults.standard.set(true, forKey: id)
        if id == backupFeatureID {
            isBackupFeatureUnlocked = true
        }
    }
    
    func isFeatureAvailable(_ featureID: String) -> Bool {
        if featureID == backupFeatureID {
            return isBackupFeatureUnlocked
        }
        return false
    }
    
    func resetPurchases() {
        UserDefaults.standard.set(false, forKey: backupFeatureID)
        isBackupFeatureUnlocked = false
    }
    
    func purchaseFeature(id: String, completion: @escaping (Bool, String?) -> Void) {
        guard AppStore.canMakePayments else {
            completion(false, "In-App-Käufe sind deaktiviert.")
            return
        }
        
        Task {
            await executePurchase(id: id, completion: completion)
        }
    }
    
    private func executePurchase(id: String, completion: @escaping (Bool, String?) -> Void) async {
        purchaseInProgress = true
        lastErrorMessage = nil
        
        do {
            let products = try await Product.products(for: [id])
            guard let product = products.first else {
                purchaseInProgress = false
                lastErrorMessage = "Produkt nicht gefunden."
                completion(false, lastErrorMessage)
                return
            }
            
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                savePurchasedFeature(id: transaction.productID)
                await transaction.finish()
                purchaseInProgress = false
                completion(true, nil)
            case .userCancelled:
                purchaseInProgress = false
                completion(false, "Kauf abgebrochen.")
            case .pending:
                purchaseInProgress = false
                completion(false, "Kauf wartet auf Bestätigung.")
            @unknown default:
                purchaseInProgress = false
                completion(false, "Unbekanntes Kaufresultat.")
            }
        } catch {
            purchaseInProgress = false
            lastErrorMessage = error.localizedDescription
            completion(false, error.localizedDescription)
        }
    }
    
    private func checkVerified(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transaktion konnte nicht verifiziert werden."])
        case .verified(let transaction):
            return transaction
        }
    }
    
    private func observeTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == backupFeatureID {
                    savePurchasedFeature(id: transaction.productID)
                }
                await transaction.finish()
            } catch {
                print("Fehler beim Verarbeiten einer Transaktion: \(error.localizedDescription)")
            }
        }
    }
}
