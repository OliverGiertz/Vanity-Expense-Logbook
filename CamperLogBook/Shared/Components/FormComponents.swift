import SwiftUI
import CoreLocation

// A collection of reusable form components to maintain consistency and reduce code duplication

// MARK: - Basic Input Fields

struct DatePickerField: View {
    var label: String
    @Binding var date: Date

    var body: some View {
        DatePicker(label, selection: $date, displayedComponents: .date)
            .submitLabel(.done)
            .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

struct DecimalField: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""
    var isEnabled: Bool = true

    var body: some View {
        TextField(placeholder.isEmpty ? label : placeholder, text: $text)
            .keyboardType(.decimalPad)
            .submitLabel(.done)
            .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            .disabled(!isEnabled)
    }
}

struct NumberField: View {
    var label: String
    @Binding var text: String
    var placeholder: String = ""

    var body: some View {
        TextField(placeholder.isEmpty ? label : placeholder, text: $text)
            .keyboardType(.numberPad)
            .submitLabel(.done)
            .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    }
}

// MARK: - Receipt Sections

/// Displays an existing receipt image/PDF and allows selecting a new one.
/// Use `clearsOnSelect: true` in Edit forms to clear the old receipt before picking a new one.
struct ReceiptPickerSection: View {
    @Binding var receiptImage: UIImage?
    @Binding var pdfData: Data?
    @Binding var showingReceiptOptions: Bool
    @Binding var receiptSource: ReceiptSource?
    var buttonLabel: String = "Beleg auswählen"
    var clearsOnSelect: Bool = false

    var body: some View {
        Section(header: Text("Beleg (Bild/PDF)")) {
            if let image = receiptImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
            } else if pdfData != nil {
                Image(systemName: "doc.richtext")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
            }
            Button(buttonLabel) {
                if clearsOnSelect {
                    receiptImage = nil
                    pdfData = nil
                }
                showingReceiptOptions = true
            }
            .confirmationDialog("Beleg Quelle wählen", isPresented: $showingReceiptOptions, titleVisibility: .visible) {
                Button("Aus Fotos wählen") { receiptSource = .photo }
                Button("Aus Dateien (PDF) wählen") { receiptSource = .pdf }
                Button("Kamera Scannen") { receiptSource = .scanner }
                Button("Abbrechen", role: .cancel) { }
            }
        }
    }
}

/// Shows a tappable preview of the current receipt (image or PDF icon).
/// Only renders when a receipt exists. Pass `showDetailAction` to open the full-screen detail view.
struct ReceiptPreviewSection: View {
    var receiptImage: UIImage?
    var pdfData: Data?
    var showDetailAction: () -> Void

    var body: some View {
        if receiptImage != nil || pdfData != nil {
            Section(header: Text("Belegvorschau")) {
                Button(action: showDetailAction) {
                    if let image = receiptImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                    } else if pdfData != nil {
                        Image(systemName: "doc.richtext")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                    }
                }
            }
        }
    }
}

// MARK: - Location Section

/// Location toggle + display + manual picker button.
/// Pass `locationManager: nil` in Edit forms where auto-location is not available.
struct LocationSection: View {
    @Binding var saveLocation: Bool
    var manualAddress: String
    var locationManager: LocationManager?
    var manualLocation: CLLocationCoordinate2D?
    var address: String?
    var showPickerAction: () -> Void

    var body: some View {
        Section(header: Text("Standort")) {
            Toggle("Standort speichern", isOn: $saveLocation)
            if saveLocation {
                if !manualAddress.isEmpty {
                    Text("Manuell ausgewählt: \(manualAddress)")
                } else if let lm = locationManager, lm.lastLocation != nil {
                    Text("Automatisch ermittelt: \(lm.address)")
                } else if let loc = manualLocation {
                    Text("Manuell ausgewählt: Lat: \(loc.latitude), Lon: \(loc.longitude)")
                } else if let address = address, !address.isEmpty {
                    Text(address)
                } else {
                    Text("Kein Standort ermittelt")
                }
                Button("Standort manuell auswählen") {
                    showPickerAction()
                }
            } else {
                Text("Standort wird nicht gespeichert")
            }
        }
    }
}

// MARK: - Save / Delete Section

struct SaveDeleteSection: View {
    var saveAction: () -> Void
    var deleteAction: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Section {
            Button("Speichern") {
                saveAction()
            }
            .disabled(isLoading)
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                    }
                }
            )
        }

        Section {
            Button(role: .destructive) {
                deleteAction()
            } label: {
                Text("Eintrag löschen")
            }
            .disabled(isLoading)
        }
    }
}

// MARK: - Error Alert Modifier

/// Attaches a standardised error alert and the "Log senden" mail sheet to any view.
struct ErrorAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    var message: String
    @Binding var showMailView: Bool

    func body(content: Content) -> some View {
        content
            .alert(isPresented: $isPresented) {
                Alert(
                    title: Text("Fehler"),
                    message: Text(message),
                    primaryButton: .default(Text("OK")),
                    secondaryButton: .default(Text("Log senden"), action: {
                        showMailView = true
                    })
                )
            }
            .sheet(isPresented: $showMailView) {
                if let url = ErrorLogger.shared.getLogFileURL(),
                   let logData = try? Data(contentsOf: url) {
                    MailComposeView(
                        recipients: ["logfile@vanityontour.de"],
                        subject: "Fehlerlog",
                        messageBody: "Bitte prüfe den beigefügten Fehlerlog.",
                        attachmentData: logData,
                        attachmentMimeType: "text/plain",
                        attachmentFileName: "error.log"
                    )
                } else {
                    Text("Logdatei nicht verfügbar.")
                }
            }
    }
}

extension View {
    func errorAlert(isPresented: Binding<Bool>, message: String, showMailView: Binding<Bool>) -> some View {
        modifier(ErrorAlertModifier(isPresented: isPresented, message: message, showMailView: showMailView))
    }
}
