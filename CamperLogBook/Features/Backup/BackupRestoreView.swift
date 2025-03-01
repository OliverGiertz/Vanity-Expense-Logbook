import SwiftUI
import CoreData

/// Subview für einen einzelnen Backup-Eintrag
struct BackupRowView: View {
    let backup: LocalBackupManager.BackupInfo
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

    // Direkt als let deklariert, damit alle Member direkt verfügbar sind.
    private let backupManager = LocalBackupManager.shared

    @State private var showBackupConfirmation = false
    @State private var showRestoreConfirmation = false
    @State private var backupToRestore: String? = nil
    @State private var showDeleteConfirmation = false
    @State private var backupToDelete: String? = nil
    @State private var showResultAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var showExportSheet = false
    @State private var showImportPicker = false
    @State private var exportURL: URL? = nil

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private var automaticBackupBinding: Binding<Bool> {
        Binding(
            get: { backupManager.isAutomaticBackupEnabled },
            set: { newValue in
                if newValue {
                    backupManager.enableAutomaticBackups()
                } else {
                    backupManager.disableAutomaticBackups()
                }
            }
        )
    }

    // Backup-Status-Ansicht
    private var backupStatusView: some View {
        Group {
            if backupManager.lastBackupStatus == .available, let date = backupManager.lastBackupDate {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Letztes Backup: \(dateFormatter.string(from: date))")
                }
            } else if backupManager.lastBackupStatus == .notAvailable {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Kein Backup vorhanden")
                }
            } else if backupManager.lastBackupStatus == .error {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(backupManager.lastErrorMessage ?? "Unbekannter Fehler")
                }
            } else {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.gray)
                    Text("Backup-Status wird geprüft...")
                }
            }
        }
    }

    var body: some View {
        List {
            backupSection
            automaticBackupSection
            availableBackupsSection
            importExportSection
        }
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            backupManager.connect(to: viewContext)
            backupManager.loadAvailableBackups()
        }
        .alert(isPresented: $showBackupConfirmation, content: backupConfirmationAlert)
        .confirmationDialog("Backup wiederherstellen", isPresented: $showRestoreConfirmation, titleVisibility: .visible) {
            if let backupID = backupToRestore {
                Button("Wiederherstellen", role: .destructive) {
                    restoreBackup(id: backupID)
                }
                Button("Abbrechen", role: .cancel) { backupToRestore = nil }
            }
        } message: {
            Text("Möchtest du deine Daten aus dem ausgewählten Backup wiederherstellen? Die bestehenden Daten werden zusammengeführt.")
        }
        .confirmationDialog("Backup löschen", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            if let backupID = backupToDelete {
                Button("Löschen", role: .destructive) {
                    deleteBackup(id: backupID)
                }
                Button("Abbrechen", role: .cancel) { backupToDelete = nil }
            }
        } message: {
            Text("Möchtest du dieses Backup wirklich löschen? Diese Aktion kann nicht rückgängig gemacht werden.")
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
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ExportBackupView(directoryURL: url)
            }
        }
        .sheet(isPresented: $showImportPicker) {
            DocumentPickerView { url in
                if let url = url {
                    LocalBackupManager.shared.importBackup(from: url, completion: { success, errorMessage in
                        alertTitle = success ? "Backup importiert" : "Import fehlgeschlagen"
                        alertMessage = success ? "Das Backup wurde erfolgreich importiert." : (errorMessage ?? "Unbekannter Fehler")
                        isSuccess = success
                        showResultAlert = true
                    })
                }
            }
        }
    }

    // MARK: - Sektionen

    private var backupSection: some View {
        Section(header: Text("Lokales Backup")) {
            HStack {
                Image(systemName: "externaldrive")
                    .font(.title)
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Lokales Backup")
                        .font(.headline)
                    Text("Sichere alle deine Daten und Belege auf deinem Gerät")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if backupManager.isBackupInProgress {
                ProgressView(value: backupManager.backupProgress) {
                    Text("Backup wird erstellt...")
                }
            } else if backupManager.isRestoreInProgress {
                ProgressView(value: backupManager.restoreProgress) {
                    Text("Backup wird wiederhergestellt...")
                }
            } else {
                backupStatusView
                Button(action: { showBackupConfirmation = true }) {
                    HStack {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Backup jetzt erstellen")
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

    private var availableBackupsSection: some View {
        Section(header: Text("Verfügbare Backups")) {
            ForEach(backupManager.availableBackups) { backup in
                BackupRowView(backup: backup, dateFormatter: dateFormatter)
                    .swipeActions {
                        Button(role: .destructive) {
                            backupToDelete = backup.id
                            showDeleteConfirmation = true
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        Button {
                            backupToRestore = backup.id
                            showRestoreConfirmation = true
                        } label: {
                            Label("Wiederherstellen", systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                        Button {
                            exportBackup(id: backup.id)
                        } label: {
                            Label("Exportieren", systemImage: "square.and.arrow.up")
                        }
                        .tint(.green)
                    }
            }
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

    // MARK: - Alerts

    private func backupConfirmationAlert() -> Alert {
        Alert(
            title: Text("Backup erstellen"),
            message: Text("Möchtest du ein neues Backup deiner Daten erstellen?"),
            primaryButton: .default(Text("Backup erstellen"), action: createBackup),
            secondaryButton: .cancel(Text("Abbrechen"))
        )
    }

    // MARK: - Aktionen

    private func createBackup() {
        backupManager.createBackup { success, errorMessage in
            alertTitle = success ? "Backup erstellt" : "Backup fehlgeschlagen"
            alertMessage = success ? "Deine Daten wurden erfolgreich gesichert." : (errorMessage ?? "Unbekannter Fehler")
            isSuccess = success
            showResultAlert = true
        }
    }

    private func restoreBackup(id: String) {
        backupManager.restoreBackup(backupID: id) { success, errorMessage in
            alertTitle = success ? "Backup wiederhergestellt" : "Wiederherstellung fehlgeschlagen"
            alertMessage = success ? "Deine Daten wurden erfolgreich wiederhergestellt." : (errorMessage ?? "Unbekannter Fehler")
            isSuccess = success
            showResultAlert = true
        }
    }

    private func deleteBackup(id: String) {
        backupManager.deleteBackup(backupID: id) { success, errorMessage in
            if !success {
                alertTitle = "Löschen fehlgeschlagen"
                alertMessage = errorMessage ?? "Unbekannter Fehler"
                isSuccess = false
                showResultAlert = true
            }
        }
    }

    private func exportBackup(id: String) {
        backupManager.exportBackup(backupID: id) { url, errorMessage in
            if let url = url {
                exportURL = url
                showExportSheet = true
            } else {
                alertTitle = "Export fehlgeschlagen"
                alertMessage = errorMessage ?? "Unbekannter Fehler"
                isSuccess = false
                showResultAlert = true
            }
        }
    }
}

struct BackupRestoreView_Previews: PreviewProvider {
    static var previews: some View {
        BackupRestoreView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
