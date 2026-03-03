import SwiftUI
import StoreKit

@available(iOS 15.0, *)
struct PremiumBackupView: View {
    @StateObject private var premiumManager = PremiumFeatureManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingRestoreAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding(.top, 40)
                        
                        Text("iCloud Backup Premium")
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Sichere deine Fahrzeugdaten automatisch")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    
                    // Feature List
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "checkmark.icloud.fill",
                            title: "Automatische Backups",
                            description: "Deine Daten werden sicher in iCloud gespeichert"
                        )
                        
                        Divider()
                        
                        FeatureRow(
                            icon: "arrow.clockwise",
                            title: "Einfache Wiederherstellung",
                            description: "Stelle deine Daten auf jedem Gerät wieder her"
                        )
                        
                        Divider()
                        
                        FeatureRow(
                            icon: "lock.shield.fill",
                            title: "End-to-End verschlüsselt",
                            description: "Deine Daten sind durch iCloud geschützt"
                        )
                        
                        Divider()
                        
                        FeatureRow(
                            icon: "infinity",
                            title: "Einmaliger Kauf",
                            description: "Kein Abo, keine versteckten Kosten"
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal)
                    
                    // Pricing Section
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Text("4,99€")
                                .font(.system(size: 48, weight: .bold))
                            
                            Text("Einmaliger Kauf")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Purchase Button
                        Button(action: purchaseBackupFeature) {
                            HStack {
                                if premiumManager.purchaseInProgress {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Wird geladen...")
                                } else {
                                    Image(systemName: "cart.fill")
                                    Text("Premium freischalten")
                                }
                            }
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(premiumManager.purchaseInProgress)
                        
                        // Restore Button
                        Button(action: { showingRestoreAlert = true }) {
                            Text("Käufe wiederherstellen")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = premiumManager.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .padding(.horizontal)
                    }
                    
                    // Terms
                    VStack(spacing: 8) {
                        Text("Einmaliger Kauf, der für alle deine Geräte gilt")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button("Datenschutz") {
                                // Open privacy policy
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                            
                            Button("Nutzungsbedingungen") {
                                // Open terms
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .alert("Käufe wiederherstellen", isPresented: $showingRestoreAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Wiederherstellen") {
                restorePurchases()
            }
        } message: {
            Text("Deine früheren Käufe werden automatisch wiederhergestellt. Dies kann einen Moment dauern.")
        }
    }
    
    private func purchaseBackupFeature() {
        PremiumFeatureManager.shared.purchaseFeature(
            id: PremiumFeatureManager.shared.backupFeatureID
        ) { success, errorMessage in
            if success {
                // Show success animation/feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    dismiss()
                }
            }
        }
    }
    
    private func restorePurchases() {
        // StoreKit 2 handles restore automatically via Transaction.updates
        // Just show a success message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if premiumManager.isBackupFeatureUnlocked {
                dismiss()
            } else {
                premiumManager.lastErrorMessage = "Keine früheren Käufe gefunden."
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

@available(iOS 15.0, *)
struct PremiumBackupView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumBackupView()
    }
}
