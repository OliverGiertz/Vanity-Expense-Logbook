# Premium Feature Implementation Guide
# iCloud Backup als In-App-Purchase

> Implementierung eines Einmalkaufs für das iCloud-Backup-Feature

---

## 📋 Übersicht

Das iCloud-Backup-Feature wird als **Non-Consumable In-App-Purchase** (Einmalkauf) implementiert.

### Product Details
- **Product ID:** `com.vanityontour.camperlogbook.icloudbackup`
- **Typ:** Non-Consumable (einmaliger Kauf)
- **Preis:** 4,99€ (Empfehlung)
- **Name:** iCloud Backup Premium
- **Beschreibung:** Automatische Backups deiner Fahrzeugdaten in iCloud

---

## 🏗️ Architektur

```
┌─────────────────────────────────────────────┐
│         PremiumFeatureManager               │
│  (Zentrale Verwaltung aller Premium-Käufe) │
└─────────────┬───────────────────────────────┘
              │
              │ verwaltet
              │
┌─────────────▼───────────────────────────────┐
│         StoreKit 2 Integration              │
│  - Product.products(for:)                   │
│  - purchase()                               │
│  - Transaction.updates                      │
└─────────────┬───────────────────────────────┘
              │
              │ schaltet frei
              │
┌─────────────▼───────────────────────────────┐
│      CloudBackupManager                     │
│  (Nur verfügbar nach Kauf)                  │
└─────────────────────────────────────────────┘
```

---

## 🛠️ Implementation Steps

### 1. App Store Connect Setup

#### a) Bundle ID & Capabilities
```
Bundle ID: com.vanityontour.camperlogbook
Capabilities: 
  - iCloud (CloudKit)
  - In-App Purchase
```

#### b) In-App-Purchase erstellen
1. App Store Connect → Deine App → In-App-Käufe
2. Neues In-App-Purchase erstellen:
   - **Typ:** Non-Consumable
   - **Product ID:** `com.vanityontour.camperlogbook.icloudbackup`
   - **Reference Name:** iCloud Backup Premium
   - **Preis:** Tier 5 (4,99€)

3. Lokalisierungen hinzufügen:
   - **Deutsch:**
     - Name: iCloud Backup Premium
     - Beschreibung: Sichere deine Fahrzeugdaten automatisch in iCloud. Einmaliger Kauf, keine Abos!
   
   - **Englisch:**
     - Name: iCloud Backup Premium
     - Description: Automatically back up your vehicle data to iCloud. One-time purchase, no subscriptions!

4. Screenshot für Review hinzufügen (optional)

5. **Status:** Bereit zur Einreichung

---

### 2. Code-Integration

Die Implementierung nutzt **StoreKit 2** (verfügbar ab iOS 15.0).

#### PremiumFeatureManager.swift
✅ **Bereits implementiert!**

**Features:**
- ✅ Product-Loading
- ✅ Kaufabwicklung
- ✅ Transaction-Verifizierung
- ✅ Persistence in UserDefaults
- ✅ Automatisches Unlock nach Kauf
- ✅ Debug-Modus (automatisch freigeschaltet in DEBUG)

**Verwendung:**
```swift
// Feature-Status prüfen
let isUnlocked = PremiumFeatureManager.shared.isBackupFeatureUnlocked

// Kauf durchführen
PremiumFeatureManager.shared.purchaseFeature(
    id: "com.vanityontour.camperlogbook.icloudbackup"
) { success, errorMessage in
    if success {
        print("✅ Backup-Feature freigeschaltet!")
    } else {
        print("❌ Fehler: \(errorMessage ?? "unknown")")
    }
}
```

---

### 3. UI-Integration

#### a) Premium-Paywall View erstellen

```swift
// PremiumBackupView.swift
import SwiftUI
import StoreKit

struct PremiumBackupView: View {
    @StateObject private var premiumManager = PremiumFeatureManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Image
                    Image(systemName: "icloud.and.arrow.up.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 40)
                    
                    // Titel
                    Text("iCloud Backup Premium")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Sichere deine Daten automatisch")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "checkmark.icloud.fill",
                            title: "Automatische Backups",
                            description: "Deine Daten werden sicher in iCloud gespeichert"
                        )
                        
                        FeatureRow(
                            icon: "arrow.clockwise",
                            title: "Einfache Wiederherstellung",
                            description: "Stelle deine Daten auf jedem Gerät wieder her"
                        )
                        
                        FeatureRow(
                            icon: "lock.shield.fill",
                            title: "End-to-End verschlüsselt",
                            description: "Deine Daten sind durch iCloud geschützt"
                        )
                        
                        FeatureRow(
                            icon: "infinity",
                            title: "Einmaliger Kauf",
                            description: "Kein Abo, keine versteckten Kosten"
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Preis & Kaufbutton
                    VStack(spacing: 12) {
                        Text("4,99€")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Einmaliger Kauf")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: purchaseBackupFeature) {
                            if premiumManager.purchaseInProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Premium freischalten")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(premiumManager.purchaseInProgress)
                        
                        Button("Käufe wiederherstellen") {
                            restorePurchases()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .padding()
                    
                    // Error Message
                    if let error = premiumManager.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func purchaseBackupFeature() {
        PremiumFeatureManager.shared.purchaseFeature(
            id: PremiumFeatureManager.shared.backupFeatureID
        ) { success, errorMessage in
            if success {
                dismiss()
            }
        }
    }
    
    private func restorePurchases() {
        // StoreKit 2 behandelt Restore automatisch über Transaction.updates
        // Nutzer-Feedback geben
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

---

#### b) ProfileView Integration

```swift
// In ProfileView.swift hinzufügen:

Section(header: Text("Premium Features")) {
    if PremiumFeatureManager.shared.isBackupFeatureUnlocked {
        // Backup ist freigeschaltet
        NavigationLink(destination: BackupSettingsView()) {
            HStack {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundColor(.green)
                Text("iCloud Backup")
                Spacer()
                Text("Aktiv")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    } else {
        // Paywall zeigen
        NavigationLink(destination: PremiumBackupView()) {
            HStack {
                Image(systemName: "lock.icloud.fill")
                    .foregroundColor(.orange)
                Text("iCloud Backup freischalten")
                Spacer()
                Text("4,99€")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}
```

---

#### c) BackupSettingsView (nach Kauf sichtbar)

```swift
// BackupSettingsView.swift
import SwiftUI

struct BackupSettingsView: View {
    @StateObject private var cloudBackup = CloudBackupManager.shared
    @State private var showingRestoreAlert = false
    
    var body: some View {
        List {
            Section(header: Text("Backup Status")) {
                HStack {
                    Text("Letztes Backup")
                    Spacer()
                    if let lastBackup = cloudBackup.lastBackupDate {
                        Text(lastBackup, style: .relative)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Nie")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Status")
                    Spacer()
                    StatusBadge(status: cloudBackup.lastBackupStatus)
                }
            }
            
            Section(header: Text("Aktionen")) {
                Button(action: createBackup) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("Backup jetzt erstellen")
                        Spacer()
                        if cloudBackup.isBackupInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(cloudBackup.isBackupInProgress)
                
                Button(action: { showingRestoreAlert = true }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("Backup wiederherstellen")
                        Spacer()
                        if cloudBackup.isRestoreInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(cloudBackup.isRestoreInProgress || cloudBackup.lastBackupStatus != .available)
            }
            
            if cloudBackup.isBackupInProgress {
                Section {
                    ProgressView(value: cloudBackup.backupProgress)
                    Text("Erstelle Backup...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if cloudBackup.isRestoreInProgress {
                Section {
                    ProgressView(value: cloudBackup.restoreProgress)
                    Text("Stelle Backup wieder her...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Automatische Backups")) {
                Toggle("Automatisches Backup aktivieren", isOn: .constant(cloudBackup.isAutomaticBackupEnabled))
                    .onChange(of: cloudBackup.isAutomaticBackupEnabled) { newValue in
                        if newValue {
                            cloudBackup.enableAutomaticBackups()
                        } else {
                            cloudBackup.disableAutomaticBackups()
                        }
                    }
                
                if cloudBackup.isAutomaticBackupEnabled {
                    Text("Automatische Backups werden täglich um 2:00 Uhr erstellt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("iCloud Backup")
        .alert("Backup wiederherstellen?", isPresented: $showingRestoreAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Wiederherstellen", role: .destructive) {
                restoreBackup()
            }
        } message: {
            Text("Dies überschreibt alle aktuellen Daten mit dem letzten Backup. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
    }
    
    private func createBackup() {
        cloudBackup.createBackup { success, error in
            if let error = error {
                print("Backup failed: \(error)")
            }
        }
    }
    
    private func restoreBackup() {
        cloudBackup.restoreBackup { success, error in
            if let error = error {
                print("Restore failed: \(error)")
            }
        }
    }
}

struct StatusBadge: View {
    let status: CloudBackupManager.BackupStatus
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .available: return .green
        case .inProgress: return .blue
        case .error: return .red
        case .none, .notAvailable: return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .available: return "Verfügbar"
        case .inProgress: return "In Bearbeitung"
        case .error: return "Fehler"
        case .none: return "Kein Backup"
        case .notAvailable: return "Nicht verfügbar"
        }
    }
}
```

---

### 4. Testing

#### a) Sandbox-Testing (empfohlen)

1. **Sandbox-Tester erstellen:**
   - App Store Connect → Benutzer und Zugriff → Sandbox-Tester
   - Neue Testbenutzer mit E-Mail anlegen
   - **Wichtig:** Nicht mit echtem Apple-ID testen!

2. **Device vorbereiten:**
   - Einstellungen → App Store → von echter Apple-ID abmelden
   - App bauen und starten
   - Beim ersten Kauf nach Sandbox-Account fragen

3. **Testszenarien:**
   - ✅ Erfolgreicher Kauf
   - ✅ Abgebrochener Kauf
   - ✅ Wiederherstellung nach Neuinstallation
   - ✅ Kauf auf zweitem Gerät

#### b) StoreKit Configuration File (lokales Testen)

```swift
// In Xcode:
// 1. File → New → File → StoreKit Configuration File
// 2. Produkt hinzufügen mit korrekter ID
// 3. Scheme bearbeiten → Run → StoreKit Configuration auswählen
```

**Vorteile:**
- Kein Internet nötig
- Schnelles Testen
- Keine Sandbox-Accounts nötig

---

### 5. Production Checklist

- [ ] Bundle ID korrekt in App Store Connect
- [ ] In-App-Purchase erstellt und "Ready to Submit"
- [ ] iCloud Capability aktiviert
- [ ] CloudKit Container konfiguriert
- [ ] PremiumFeatureManager integriert
- [ ] UI für Paywall implementiert
- [ ] Sandbox-Testing durchgeführt
- [ ] TestFlight-Beta getestet
- [ ] App Review Guidelines geprüft
- [ ] Privacy Policy aktualisiert (In-App-Käufe erwähnen)

---

## 🔐 Security Best Practices

### 1. Transaction Verification
✅ Bereits implementiert in `checkVerified(_:)`

### 2. Receipt Validation
StoreKit 2 macht automatische Validation über Apple-Server.

### 3. Offline-Zugriff
Premium-Status wird in UserDefaults gespeichert für Offline-Nutzung.

---

## 🐛 Troubleshooting

### Problem: "Product not found"
**Lösung:**
- Bundle ID korrekt?
- Product ID exakt gleich?
- In-App-Purchase Status "Ready to Submit"?
- Warte 2-24h nach Erstellung

### Problem: "Cannot connect to iTunes Store"
**Lösung:**
- Sandbox-Tester korrekt angemeldet?
- Internet-Verbindung?
- StoreKit Configuration im Scheme aktiviert?

### Problem: Kauf wird nicht freigeschaltet
**Lösung:**
- `Transaction.updates` Observer läuft?
- UserDefaults Key korrekt?
- Debug-Logging aktivieren

---

## 📊 Analytics (optional)

```swift
// Nach erfolgreichem Kauf tracken
Analytics.logEvent("premium_purchase", parameters: [
    "product_id": transaction.productID,
    "price": "4.99",
    "currency": "EUR"
])
```

---

## 🚀 Launch-Strategie

### Soft Launch (Beta)
1. TestFlight mit 50-100 Testern
2. Feedback sammeln
3. Bugs fixen

### Public Launch
1. App Store Review einreichen
2. Pressemitteilung vorbereiten
3. Social Media Kampagne

### Post-Launch
1. Conversion-Rate monitoren
2. A/B-Testing der Paywall
3. User-Feedback auswerten

---

## 💰 Pricing-Überlegungen

| Preis | Pros | Cons |
|-------|------|------|
| 2,99€ | Niedrige Einstiegshürde | Geringerer Umsatz |
| **4,99€** | **Sweet Spot für Utilities** | **Ausgewogen** |
| 9,99€ | Höherer Umsatz pro Kauf | Reduzierte Conversion |

**Empfehlung:** 4,99€ mit gelegentlichen Rabattaktionen.

---

## 📱 App Store Screenshots

### Empfohlene Screenshot-Strategie:
1. **Screen 1:** App-Übersicht (kostenlose Features)
2. **Screen 2:** Premium-Features Highlight
3. **Screen 3:** iCloud Backup in Aktion
4. **Screen 4:** Statistiken & Analytics
5. **Screen 5:** "Trusted by X users" Social Proof

---

## 📄 Datenschutz & Legal

### Privacy Policy Update nötig:
```
In-App-Käufe:
Unsere App bietet Premium-Features als Einmalkauf an. 
Wir sammeln keine Zahlungsinformationen. Alle Transaktionen 
werden sicher über Apple's App Store abgewickelt.

iCloud Backup:
Bei Aktivierung des Premium-Features werden Ihre Daten 
verschlüsselt in Ihrer persönlichen iCloud gespeichert.
```

---

## ✅ Fertig!

Nach Implementation solltest du:
1. ✅ Einmalkauf für Backup funktionsfähig
2. ✅ Elegante Paywall-UI
3. ✅ Sichere Transaction-Handling
4. ✅ Sandbox getestet
5. ✅ Bereit für App Store

---

_Bei Fragen: GitHub Issues oder direkte Nachricht!_ 🚀
