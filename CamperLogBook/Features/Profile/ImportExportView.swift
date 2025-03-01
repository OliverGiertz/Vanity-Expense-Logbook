import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ImportExportView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // Import
    @State private var selectedImportType: CSVHelperEntryType = .fuel
    @State private var showingDocumentPicker = false
    @State private var importResultMessage: String?
    @State private var showingImportAlert = false

    // Export
    @State private var exportFuel = true
    @State private var exportGas = true
    @State private var exportOther = true
    @State private var exportCSVString: String?
    @State private var showingActivityView = false

    var body: some View {
        Form {
            Section(header: Text("CSV Import")) {
                Picker("Eintragstyp", selection: $selectedImportType) {
                    Text("Tankbeleg").tag(CSVHelperEntryType.fuel)
                    Text("Gaskosten").tag(CSVHelperEntryType.gas)
                    Text("Sonstige Kosten").tag(CSVHelperEntryType.other)
                }
                .pickerStyle(SegmentedPickerStyle())
                Button("CSV Datei auswählen") {
                    showingDocumentPicker = true
                }
            }
            Section(header: Text("CSV Export")) {
                Toggle("Tankbeleg exportieren", isOn: $exportFuel)
                Toggle("Gaskosten exportieren", isOn: $exportGas)
                Toggle("Sonstige Kosten exportieren", isOn: $exportOther)
                Button("CSV exportieren") {
                    exportCSV()
                }
            }
        }
        .navigationTitle("CSV Import/Export")
        .sheet(isPresented: $showingDocumentPicker) {
            CSVDocumentPickerView { url in
                if let url = url {
                    do {
                        let count = try CSVHelper.importCSV(for: selectedImportType, from: url, in: viewContext)
                        importResultMessage = "\(count) Einträge importiert."
                    } catch {
                        importResultMessage = "Importfehler: \(error.localizedDescription)"
                    }
                    showingImportAlert = true
                }
                showingDocumentPicker = false
            }
        }
        .sheet(isPresented: $showingActivityView, onDismiss: {
            exportCSVString = nil
        }) {
            if let csv = exportCSVString {
                ActivityView(activityItems: [csv])
            }
        }
        .alert(isPresented: $showingImportAlert) {
            Alert(title: Text("Import Ergebnis"), message: Text(importResultMessage ?? ""), dismissButton: .default(Text("OK")))
        }
    }

    private func exportCSV() {
        var types: [CSVHelperEntryType] = []
        if exportFuel { types.append(.fuel) }
        if exportGas { types.append(.gas) }
        if exportOther { types.append(.other) }
        let csv = CSVHelper.generateCSV(forTypes: types, in: viewContext)
        exportCSVString = csv
        showingActivityView = true
    }
}

/// Spezieller DocumentPicker speziell für CSV-Dateien
struct CSVDocumentPickerView: UIViewControllerRepresentable {
    var completion: (URL?) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes = [UTType.commaSeparatedText, UTType.tabSeparatedText, UTType.text, UTType.plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var completion: (URL?) -> Void
        
        init(completion: @escaping (URL?) -> Void) {
            self.completion = completion
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls.first)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil)
        }
    }
}

struct ImportExportView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ImportExportView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        }
    }
}
