import SwiftUI
import MapKit

extension CLLocationCoordinate2D: Identifiable {
    public var id: String { "\(latitude),\(longitude)" }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        latitudinalMeters: 1000000,
        longitudinalMeters: 1000000
    )

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [region.center]) { coordinate in
            MapMarker(coordinate: coordinate, tint: .red)
        }
        .frame(height: 300)
        .overlay(
            Text("Mitte der Karte = gewählter Standort")
                .padding(6)
                .background(Color.white.opacity(0.8))
                .cornerRadius(8)
                .padding(), alignment: .top
        )
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Übernehmen") {
                    selectedCoordinate = region.center
                    dismiss()
                }
            }
        }
        .navigationTitle("Standort wählen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LocationPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LocationPickerView(selectedCoordinate: .constant(nil))
        }
    }
}
