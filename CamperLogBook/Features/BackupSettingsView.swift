import SwiftUI

@available(iOS 15.0, *)
struct BackupSettingsView: View {
    @StateObject private var cloudBackup = CloudBackupManager.shared
    @StateObject private var premiumManager = PremiumFeatureManager.shared
    @State private var showingRestoreAlert = false
    @State private var showingBackupSuccessAlert = false
    @State private var showingRestoreSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            // Premium Status
            Section {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Premium-Feature aktiv")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Backup Status
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
                
                if let error = cloudBackup.lastErrorMessage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Letzte Fehlermeldung")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Progress Indicators
            if cloudBackup.isBackupInProgress {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Erstelle Backup...")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(cloudBackup.backupProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: cloudBackup.backupProgress)
                            .tint(.blue)
                    }
                }
            }
            
            if cloudBackup.isRestoreInProgress {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Stelle Backup wieder her...")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(cloudBackup.restoreProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ProgressView(value: cloudBackup.restoreProgress)
                            .tint(.green)
                    }
                }
            }
            
            // Actions
            Section(header: Text("Aktionen")) {
                Button(action: createBackup) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("Backup jetzt erstellen")
                        Spacer()
                        if cloudBackup.isBackupInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(cloudBackup.isBackupInProgress || cloudBackup.isRestoreInProgress)
                
                Button(action: { showingRestoreAlert = true }) {
                    HStack {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundColor(.green)
                        Text("Backup wiederherstellen")
                        Spacer()
                        if cloudBackup.isRestoreInProgress {
                            ProgressView()
                        }
                    }
                }
                .disabled(
                    cloudBackup.isBackupInProgress || 
                    cloudBackup.isRestoreInProgress || 
                    cloudBackup.lastBackupStatus != .available
                )
            }
            
            // Automatic Backup Settings
            Section(header: Text("Automatische Backups")) {
                Toggle(isOn: Binding(
                    get: { cloudBackup.isAutomaticBackupEnabled },
                    set: { newValue in
                        if newValue {
                            cloudBackup.enableAutomaticBackups()
                        } else {
                            cloudBackup.disableAutomaticBackups()
                        }
                    }
                )) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.orange)
                        Text("Automatisches Backup")
                    }
                }
                
                if cloudBackup.isAutomaticBackupEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatische Backups werden täglich um 2:00 Uhr erstellt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Stelle sicher, dass dein Gerät mit WLAN verbunden ist")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Info Section
            Section(header: Text("Informationen")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Was wird gesichert?")
                            .fontWeight(.medium)
                    }
                    
                    Text("• Alle Tankbelege\n• Gaseinträge\n• Service-Einträge\n• Sonstige Kosten\n• Belege und Fotos\n• Fahrzeugprofil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.green)
                        Text("Datensicherheit")
                            .fontWeight(.medium)
                    }
                    
                    Text("Deine Daten werden verschlüsselt in deiner persönlichen iCloud gespeichert und sind nur für dich zugänglich.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
            }
        }
        .navigationTitle("iCloud Backup")
        .navigationBarTitleDisplayMode(.large)
        .alert("Backup wiederherstellen?", isPresented: $showingRestoreAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Wiederherstellen", role: .destructive) {
                restoreBackup()
            }
        } message: {
            Text("Dies überschreibt alle aktuellen Daten mit dem letzten Backup. Dieser Vorgang kann nicht rückgängig gemacht werden.")
        }
        .alert("Backup erstellt", isPresented: $showingBackupSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Deine Daten wurden erfolgreich in iCloud gesichert.")
        }
        .alert("Backup wiederhergestellt", isPresented: $showingRestoreSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Deine Daten wurden erfolgreich wiederhergestellt.")
        }
        .alert("Fehler", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func createBackup() {
        cloudBackup.createBackup { success, error in
            DispatchQueue.main.async {
                if success {
                    showingBackupSuccessAlert = true
                } else {
                    errorMessage = error ?? "Unbekannter Fehler"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func restoreBackup() {
        cloudBackup.restoreBackup { success, error in
            DispatchQueue.main.async {
                if success {
                    showingRestoreSuccessAlert = true
                } else {
                    errorMessage = error ?? "Unbekannter Fehler"
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: CloudBackupManager.BackupStatus
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(statusColor.opacity(0.15))
        )
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

@available(iOS 15.0, *)
struct BackupSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BackupSettingsView()
        }
    }
}
