//
//  PremiumFeatureView.swift
//  CamperLogBook
//
//  Created by Oliver Giertz on 27.02.25.
//


import SwiftUI

/// Ansicht zum Kauf von Premium-Features
struct PremiumFeatureView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var premiumManager = PremiumFeatureManager.shared
    
    @State private var showPurchaseSuccess = false
    @State private var showPurchaseError = false
    
    var featureID: String
    var featureName: String
    var featureDescription: String
    var featureIcon: String
    var price: String
    
    var body: some View {
        VStack(spacing: 20) {
            // Header mit Feature-Symbol
            VStack {
                Image(systemName: featureIcon)
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding()
                
                Text(featureName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(featureDescription)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 30)
            
            Spacer()
            
            // Feature-Details
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "checkmark.circle.fill", text: "Alle Daten sicher in der iCloud speichern")
                FeatureRow(icon: "checkmark.circle.fill", text: "Automatische tägliche Backups")
                FeatureRow(icon: "checkmark.circle.fill", text: "Einfache Wiederherstellung bei Gerätewechsel")
                FeatureRow(icon: "checkmark.circle.fill", text: "Mehrere Geräte synchronisieren")
            }
            .padding()
            
            Spacer()
            
            // Kaufbutton
            Button(action: purchaseFeature) {
                if premiumManager.purchaseInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else {
                    Text("Premium-Feature freischalten")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                }
            }
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding()
            .disabled(premiumManager.purchaseInProgress || premiumManager.isFeatureAvailable(featureID))
            
            // Preis-Info
            Text("\(premiumManager.isFeatureAvailable(featureID) ? "Bereits freigeschaltet" : "Einmaliger Kauf: \(price)")")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .padding()
        .navigationTitle("Premium-Feature")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Kauf erfolgreich", isPresented: $showPurchaseSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Vielen Dank für deinen Kauf! Du kannst jetzt das \(featureName)-Feature nutzen.")
        }
        .alert("Fehler beim Kauf", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(premiumManager.lastErrorMessage ?? "Unbekannter Fehler")
        }
    }
    
    private func purchaseFeature() {
        premiumManager.purchaseFeature(id: featureID) { success, _ in
            if success {
                showPurchaseSuccess = true
            } else {
                showPurchaseError = true
            }
        }
    }
}

struct FeatureRow: View {
    var icon: String
    var text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.green)
            
            Text(text)
                .font(.body)
        }
    }
}

struct PremiumFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PremiumFeatureView(
                featureID: "com.example.backupfeature",
                featureName: "iCloud Backup",
                featureDescription: "Sichere alle deine Daten in der iCloud",
                featureIcon: "icloud.fill",
                price: "4,99 €"
            )
        }
    }
}