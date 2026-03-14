import Testing
import Foundation
@testable import CamperLogBook

@Suite("PremiumFeatureManager")
@MainActor
struct PremiumFeatureManagerTests {

    private let featureID = "com.vanityontour.camperlogbook.icloudbackup"

    // MARK: - resetPurchases

    @Test func resetPurchases_setsUnlockedToFalse() {
        let manager = PremiumFeatureManager.shared
        manager.resetPurchases()
        #expect(manager.isBackupFeatureUnlocked == false)
    }

    @Test func resetPurchases_clearsUserDefaults() {
        let manager = PremiumFeatureManager.shared
        UserDefaults.standard.set(true, forKey: featureID)
        manager.resetPurchases()
        #expect(UserDefaults.standard.bool(forKey: featureID) == false)
    }

    // MARK: - isFeatureAvailable

    @Test func isFeatureAvailable_returnsFalseAfterReset() {
        let manager = PremiumFeatureManager.shared
        manager.resetPurchases()
        #expect(manager.isFeatureAvailable(featureID) == false)
    }

    @Test func isFeatureAvailable_unknownFeature_returnsFalse() {
        let manager = PremiumFeatureManager.shared
        #expect(manager.isFeatureAvailable("com.unknown.feature") == false)
    }
}
