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

/// Gruppiert FuelEntry-Einträge anhand gerundeter GPS-Werte.
struct FuelGroup: Identifiable {
    let id: String  // z. B. "51.1221,6.9248"
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let totalCost: Double
}

struct FuelMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager

    @State private var selectedPeriod: FilterPeriod = .oneMonth
    @State private var fuelEntries: [FuelEntry] = []
    @State private var cachedFuelGroups: [FuelGroup] = [] // Gruppierte Daten werden hier gespeichert
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedGroupID: String? = nil

    var body: some View {
        NavigationView {
            VStack {
                Picker("Zeitraum", selection: $selectedPeriod) {
                    ForEach(FilterPeriod.allCases) { period in
                        Text("\(period.rawValue) (\(countEntries(for: period)))")
                            .tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                .onChange(of: selectedPeriod) { _ in loadEntries() }

                if !cachedFuelGroups.isEmpty {
                    Map(coordinateRegion: $region, annotationItems: cachedFuelGroups) { group in
                        MapAnnotation(coordinate: group.coordinate) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(selectedGroupID == group.id ? .blue : .red)
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
                    if let userLocation = locationManager.lastLocation {
                        let userAnnotation = IdentifiableCoordinate(coordinate: userLocation.coordinate)
                        Map(coordinateRegion: $region, annotationItems: [userAnnotation]) { item in
                            MapAnnotation(coordinate: item.coordinate) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                            }
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
                loadEntries()
            }
        }
    }

    private func countEntries(for period: FilterPeriod) -> Int {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .month, value: -period.months, to: Date()) else { return 0 }
        let now = Date()
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND latitude != 0 AND longitude != 0",
                                    startDate as NSDate, now as NSDate)
        let request: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        request.predicate = predicate
        do {
            return try viewContext.count(for: request)
        } catch {
            print("Fehler beim Zählen der Einträge: \(error)")
            return 0
        }
    }

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

    private func loadEntries() {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .month, value: -selectedPeriod.months, to: Date()) else { return }
        let now = Date()
        let predicate = NSPredicate(format: "date >= %@ AND date <= %@ AND latitude != 0 AND longitude != 0",
                                    startDate as NSDate, now as NSDate)
        let request: NSFetchRequest<FuelEntry> = FuelEntry.fetchRequest() as! NSFetchRequest<FuelEntry>
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            let entries = try viewContext.fetch(request)
            fuelEntries = entries
            cachedFuelGroups = computeFuelGroups(from: entries)
            selectedGroupID = nil
        } catch {
            print("Error fetching FuelEntries: \(error)")
            fuelEntries = []
            cachedFuelGroups = []
        }
    }

    // Diese Funktion berechnet die FuelGroups aus den Einträgen.
    private func computeFuelGroups(from entries: [FuelEntry]) -> [FuelGroup] {
        let grouped = Dictionary(grouping: entries) { entry -> String in
            // Hier könntest du auch entry.roundedLatitude und entry.roundedLongitude verwenden
            let roundedLat = (entry.latitude * 10000).rounded() / 10000
            let roundedLon = (entry.longitude * 10000).rounded() / 10000
            return "\(roundedLat),\(roundedLon)"
        }
        var result: [FuelGroup] = []
        for (key, groupEntries) in grouped {
            if let first = groupEntries.first {
                let coordinate = CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude)
                let count = groupEntries.count
                let totalCost = groupEntries.reduce(0.0) { $0 + $1.totalCost }
                result.append(FuelGroup(id: key, coordinate: coordinate, count: count, totalCost: totalCost))
            }
        }
        return result
    }
}

struct FuelMapView_Previews: PreviewProvider {
    static var previews: some View {
        FuelMapView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            .environmentObject(LocationManager())
    }
}
