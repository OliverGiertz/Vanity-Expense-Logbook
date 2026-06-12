import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var selectedAddress: String

    private static let defaultMapCenter = CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515)

    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: Self.defaultMapCenter,
        latitudinalMeters: 1_000_000,
        longitudinalMeters: 1_000_000
    ))
    @State private var centerCoordinate = Self.defaultMapCenter

    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false

    var body: some View {
        VStack {
            // Suchleiste
            HStack {
                TextField("Adresse suchen", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disableAutocorrection(true)
                Button("Suchen") {
                    searchAddress()
                }
                .disabled(searchQuery.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
            }
            .padding()

            Map(position: $cameraPosition) {
                Annotation("", coordinate: centerCoordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .onMapCameraChange { context in
                centerCoordinate = context.region.center
            }
            .frame(height: 300)
            .overlay(
                Text("Mitte der Karte = gewählter Standort")
                    .padding(6)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(8)
                    .padding(),
                alignment: .top
            )

            // Zeige die gefundene Adresse an (falls vorhanden)
            if !selectedAddress.isEmpty {
                Text("Gefundene Adresse: \(selectedAddress)")
                    .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Übernehmen") {
                    selectedCoordinate = centerCoordinate
                    dismiss()
                }
            }
        }
        .navigationTitle("Standort wählen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func searchAddress() {
        isSearching = true
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(searchQuery) { placemarks, error in
            DispatchQueue.main.async {
                self.isSearching = false
                if let error = error {
                    ErrorLogger.shared.log(error: error, additionalInfo: "Geocode in LocationPickerView")
                    return
                }
                if let placemark = placemarks?.first, let location = placemark.location {
                    let newRegion = MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                    )
                    self.centerCoordinate = location.coordinate
                    self.cameraPosition = .region(newRegion)
                    var addressComponents: [String] = []
                    if let name = placemark.name { addressComponents.append(name) }
                    if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
                    if let locality = placemark.locality { addressComponents.append(locality) }
                    if let country = placemark.country { addressComponents.append(country) }
                    self.selectedAddress = addressComponents.joined(separator: ", ")
                }
            }
        }
    }
}

struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LocationPickerView(selectedCoordinate: .constant(nil), selectedAddress: .constant(""))
        }
    }
}
