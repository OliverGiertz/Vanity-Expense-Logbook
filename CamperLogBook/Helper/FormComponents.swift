import SwiftUI
import CoreLocation

// A collection of reusable form components to maintain consistency and reduce code duplication

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

struct ReceiptPreviewSection: View {
    var receiptImage: UIImage?
    var pdfData: Data?
    var showDetailAction: () -> Void
    
    var body: some View {
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

struct LocationSection: View {
    @Binding var saveLocation: Bool
    var manualAddress: String
    var locationManager: LocationManager
    var manualLocation: CLLocationCoordinate2D?
    var address: String?
    var showPickerAction: () -> Void
    
    var body: some View {
        Section(header: Text("Standort")) {
            Toggle("Standort speichern", isOn: $saveLocation)
            if saveLocation {
                if !manualAddress.isEmpty {
                    Text("Manuell ausgewählt: \(manualAddress)")
                } else if let _ = locationManager.lastLocation {
                    Text("Automatisch ermittelt: \(locationManager.address)")
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
