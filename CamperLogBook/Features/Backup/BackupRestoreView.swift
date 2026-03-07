import SwiftUI
import CoreData

/// Subview für einen einzelnen Backup-Eintrag
struct BackupRowView: View {
    let backup: LocalBackupManager.BackupInfo  // Hier ggf. den Typ anpassen, falls du BackupInfo neu definierst
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateFormatter.string(from: backup.date))
                .font(.headline)
            Text("Version: \(backup.version)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct BackupRestoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // Verwende jetzt den CloudBackupManager
    @StateObject private var backupManager = CloudBackupManager.shared

    @State private var showBackupConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showResultAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var exportURL: URL?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var automaticBackupBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "automaticBackupsEnabled") },
            set: { newValue in
                if newValue {
                    backupManager.enableAutomaticBackups()
                } else {
                    backupManager.disableAutomaticBackups()
                }
            }
        )
    }

    var body: some View {
        List {
            backupSection
            automaticBackupSection
            // Da die bisherige lokale Backup-Auflistung nun ersetzt wird,
            // müssten hier ggf. andere UI-Komponenten verwendet werden.
            // Für dieses Beispiel belassen wir diesen Teil vorerst unverändert.
            importExportSection
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            backupManager.connect(to: viewContext)
            // Eventuell können hier weitere Informationen (z. B. letzes Backup) aus CloudKit geladen werden.
        }
        .alert(isPresented: $showBackupConfirmation, content: backupConfirmationAlert)
        .confirmationDialog("Backup wiederherstellen", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            Button("Wiederherstellen", role: .destructive) {
                restoreBackup()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Möchtest du deine Daten aus dem Backup wiederherstellen? Bestehende Daten werden zusammengeführt.")
        }
        .alert(alertTitle, isPresented: $showResultAlert) {
            Button("OK") {
                if isSuccess && alertTitle.contains("wiederhergestellt") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }

    private var backupSection: some View {
        Section(header: Text("iCloud Backup")) {
            if backupManager.isBackupInProgress {
                ProgressView(value: backupManager.backupProgress) {
                    Text("Backup wird erstellt...")
                }
            } else if backupManager.isRestoreInProgress {
                ProgressView(value: backupManager.restoreProgress) {
                    Text("Backup wird wiederhergestellt...")
                }
            } else {
                // Statusanzeige kann hier erweitert werden, z. B. "Letztes Backup: ..." falls geladen.
                Button(action: { showBackupConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Backup jetzt erstellen")
                    }
                }
                .disabled(backupManager.isBackupInProgress || backupManager.isRestoreInProgress)
                
                Button(action: { showRestoreConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Backup wiederherstellen")
                    }
                }
                .disabled(backupManager.isBackupInProgress || backupManager.isRestoreInProgress)
            }
        }
    }

    private var automaticBackupSection: some View {
        Section(header: Text("Automatisches Backup")) {
            Toggle("Tägliches Backup aktivieren", isOn: automaticBackupBinding)
            Text("Wenn aktiviert, wird jede Nacht um 2 Uhr automatisch ein Backup erstellt.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var importExportSection: some View {
        Section(header: Text("Import/Export")) {
            Button(action: { showImportPicker = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Backup importieren")
                }
            }
        }
    }
    
    private func backupConfirmationAlert() -> Alert {
        Alert(
            title: Text("Backup erstellen"),
            message: Text("Möchtest du ein neues Backup deiner Daten erstellen?"),
            primaryButton: .default(Text("Backup erstellen"), action: createBackup),
            secondaryButton: .cancel(Text("Abbrechen"))
        )
    }
    
    private func createBackup() {
        Task {
            do {
                try await backupManager.createBackup()
                alertTitle = "Backup erstellt"
                alertMessage = "Deine Daten wurden erfolgreich gesichert."
                isSuccess = true
            } catch {
                alertTitle = "Backup fehlgeschlagen"
                alertMessage = error.localizedDescription
                isSuccess = false
            }
            showResultAlert = true
        }
    }

    private func restoreBackup() {
        Task {
            do {
                try await backupManager.restoreBackup()
                alertTitle = "Backup wiederhergestellt"
                alertMessage = "Deine Daten wurden erfolgreich wiederhergestellt."
                isSuccess = true
            } catch {
                alertTitle = "Wiederherstellung fehlgeschlagen"
                alertMessage = error.localizedDescription
                isSuccess = false
            }
            showResultAlert = true
        }
    }
}
