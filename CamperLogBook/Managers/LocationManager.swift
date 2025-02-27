import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var lastLocation: CLLocation?
    @Published var address: String = "Adresse wird ermittelt..."
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // Less accurate but sufficient for city-level locations
        locationManager.distanceFilter = 100 // Only update when moved 100 meters
        // Benutzer um Erlaubnis bitten
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // Add method to request more accurate updates when needed
    func requestPreciseLocation() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.requestLocation() // Request single update
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastLocation = location
            // Reverse-Geocoding starten
            geocoder.cancelGeocode()
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                guard let self = self else { return }
                if let error = error {
                    print("Reverse geocode error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.address = "Adresse nicht verfügbar"
                    }
                } else if let placemark = placemarks?.first {
                    var addressString = ""
                    if let street = placemark.thoroughfare {
                        addressString += street
                    }
                    if let number = placemark.subThoroughfare {
                        addressString += " " + number
                    }
                    if let city = placemark.locality {
                        addressString += ", " + city
                    }
                    DispatchQueue.main.async {
                        self.address = addressString.isEmpty ? "Adresse nicht verfügbar" : addressString
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        ErrorLogger.shared.log(error: error, additionalInfo: "Location error in LocationManager")
    }
}
