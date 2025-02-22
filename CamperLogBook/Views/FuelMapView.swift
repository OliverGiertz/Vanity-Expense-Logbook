import SwiftUI
import MapKit
import CoreData

enum FilterPeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1 Monat"
    case sixMonths = "6 Monate"
    case oneYear = "1 Jahr"
    
    var id: String { self.rawValue }
    var months: Int {
        switch self {
        case .oneMonth: return 1
        case .sixMonths: return 6
        case .oneYear: return 12
        }
    }
}

/// Struktur zur Gruppierung von FuelEntry-Einträgen nach Standort.
struct FuelGroup: Identifiable {
    let id: String  // Erzeugt z. B. "51.1221,6.9248"
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let totalCost: Double
}

/// Hilfsstruktur, um einen Standort als Identifiable zu verwenden.
struct IdentifiableLocation: Identifiable {
    let coordinate: CLLocationCoordinate2D
    var id: String { "\(coordinate.latitude),\(coordinate.longitude)" }
}

struct FuelMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var selectedPeriod: FilterPeriod = .oneMonth
    @State private var fuelEntries: [FuelEntry] = []
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedGroupID: String? = nil
    
    /// Gruppiert die geladenen FuelEntry-Einträge nach gerundeten Koordinaten (4 Dezimalstellen)
    private var fuelGroups: [FuelGroup] {
        let grouped = Dictionary(grouping: fuelEntries) { (entry) -> String in
            let roundedLat = (entry.latitude * 10000).rounded() / 10000
            let roundedLon = (entry.longitude * 10000).rounded() / 10000
            return "\(roundedLat),\(roundedLon)"
        }
        return grouped.map { (key, entries) in
            let first = entries.first!
            let coordinate = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
            let count = entries.count
            let totalCost = entries.reduce(0.0) { $0 + $1.totalCost }
            return FuelGroup(id: key, coordinate: coordinate, count: count, totalCost: totalCost)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Zeitraum-Auswahl mit Anzeige der Anzahl Einträge in Klammern
                Picker("Zeitraum", selection: $selectedPeriod) {
                    ForEach(FilterPeriod.allCases) { period in
                        Text("\(period.rawValue) (\(countEntries(for: period)))").tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedPeriod) { _ in
                    loadEntries()
                }
                
                // Map-Ansicht: Zeige gruppierte Annotationen
                if !fuelGroups.isEmpty {
                    Map(coordinateRegion: $region, annotationItems: fuelGroups) { group in
                        MapAnnotation(coordinate: group.coordinate) {
                            VStack(spacing: 0) {
                                Image(systemName: "fuelpump.fill")
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.blue)
                                if selectedGroupID == group.id {
                                    Text("(\(group.count) | \(Int(round(group.totalCost)))€)")
                                        .font(.headline)
                                        .foregroundColor(.black)
                                        .padding(6)
                                        .background(Color.white)
                                        .cornerRadius(5)
                                        .shadow(radius: 2)
                                }
                            }
                            .onTapGesture {
                                if selectedGroupID == group.id {
                                    selectedGroupID = nil
                                } else {
                                    selectedGroupID = group.id
                                }
                            }
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                } else {
                    // Falls keine Einträge vorhanden, zeige den Nutzerstandort (falls vorhanden)
                    if let userLocation = locationManager.lastLocation {
                        let userLoc = IdentifiableLocation(coordinate: userLocation.coordinate)
                        Map(coordinateRegion: $region, annotationItems: [userLoc]) { loc in
                            MapMarker(coordinate: loc.coordinate, tint: .red)
                        }
                        .edgesIgnoringSafeArea(.all)
                    } else {
                        Map(coordinateRegion: $region)
                            .edgesIgnoringSafeArea(.all)
                    }
                }
            }
            .navigationTitle("Karte")
            .onAppear {
                updateRegion()
                CSVHelper.correctGPSValues(in: viewContext)
                loadEntries()
            }
        }
    }
    
    /// Zählt die FuelEntry-Einträge für einen gegebenen Filterzeitraum.
    private func countEntries(for period: FilterPeriod) -> Int {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .month, value: -period.months, to: Date()) else { return 0 }
        let now = Date()
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND latitude != 0 AND longitude != 0", startDate as NSDate, now as NSDate)
        let request: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        request.predicate = predicate
        do {
            return try viewContext.count(for: request)
        } catch {
            print("Fehler beim Zählen der Einträge: \(error)")
            return 0
        }
    }
    
    /// Aktualisiert das Kartenzentrum auf den aktuellen Standort des Nutzers, falls vorhanden.
    private func updateRegion() {
        if let userLocation = locationManager.lastLocation {
            withAnimation {
                region = MKCoordinateRegion(
                    center: userLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
    
    /// Lädt alle FuelEntry-Einträge aus Core Data, die im gewählten Zeitraum liegen und gültige GPS-Daten besitzen.
    private func loadEntries() {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .month, value: -selectedPeriod.months, to: Date()) else { return }
        let now = Date()
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND latitude != 0 AND longitude != 0", startDate as NSDate, now as NSDate)
        let request: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            fuelEntries = try viewContext.fetch(request)
            selectedGroupID = nil
        } catch {
            print("Error fetching FuelEntries: \(error)")
            fuelEntries = []
        }
    }
}

struct FuelMapView_Previews: PreviewProvider {
    static var previews: some View {
        FuelMapView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
