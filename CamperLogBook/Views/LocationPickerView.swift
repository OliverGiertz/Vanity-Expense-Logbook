import SwiftUI
import MapKit

struct IdentifiableCoordinate: Identifiable {
    let coordinate: CLLocationCoordinate2D
    var id: String { "\(coordinate.latitude),\(coordinate.longitude)" }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCoordinate: CLLocationCoordinate2D?

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        latitudinalMeters: 1_000_000,
        longitudinalMeters: 1_000_000
    )
    
    // Das Zentrum der Karte als Annotation
    private var centerAnnotations: [IdentifiableCoordinate] {
        [IdentifiableCoordinate(coordinate: region.center)]
    }
    
    var body: some View {
        Map(coordinateRegion: $region, annotationItems: centerAnnotations) { item in
            MapAnnotation(coordinate: item.coordinate) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
            }
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
