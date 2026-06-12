import CoreLocation
import CoreData

/// Centralises location-resolution logic that was previously duplicated
/// across all creation forms and all edit forms.
enum LocationHelper {

    // MARK: - Creation forms

    struct ResolvedLocation {
        let coordinate: CLLocationCoordinate2D
        let address: String
    }

    /// Returns the best available coordinate and address string for a new entry.
    /// Priority: auto-detected GPS → manually picked coordinate → (0, 0) as last resort.
    static func resolve(
        saveLocation: Bool,
        locationManager: LocationManager,
        manualCoordinate: CLLocationCoordinate2D?,
        manualAddress: String
    ) -> ResolvedLocation {
        guard saveLocation else {
            return ResolvedLocation(coordinate: .zero, address: "")
        }
        if let auto = locationManager.lastLocation {
            let addr = manualAddress.isEmpty ? locationManager.address : manualAddress
            return ResolvedLocation(coordinate: auto.coordinate, address: addr)
        }
        if let manual = manualCoordinate {
            return ResolvedLocation(coordinate: manual, address: manualAddress)
        }
        ErrorLogger.shared.log(message: "Kein Standort ermittelt – Standardkoordinaten (0,0) verwendet")
        return ResolvedLocation(coordinate: .zero, address: "")
    }

    // MARK: - Edit forms

    /// Writes location data from an edit form back to a Core Data entry.
    /// When `saveLocation` is false, coordinates and address are cleared.
    static func applyEdit(
        saveLocation: Bool,
        manualLocation: CLLocationCoordinate2D?,
        manualAddress: String,
        to entry: NSManagedObject
    ) {
        if saveLocation {
            if let loc = manualLocation {
                entry.setValue(loc.latitude, forKey: "latitude")
                entry.setValue(loc.longitude, forKey: "longitude")
            }
            if !manualAddress.isEmpty {
                entry.setValue(manualAddress, forKey: "address")
            }
        } else {
            entry.setValue(0.0, forKey: "latitude")
            entry.setValue(0.0, forKey: "longitude")
            entry.setValue("", forKey: "address")
        }
    }
}

extension CLLocationCoordinate2D {
    static var zero: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
}
