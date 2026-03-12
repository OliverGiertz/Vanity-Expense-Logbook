import SwiftUI
import MapKit
import CoreData

enum FilterPeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1 Monat"
    case threeMonths = "3 Monate"
    case sixMonths = "6 Monate"
    case oneYear = "1 Jahr"

    var id: String { self.rawValue }
    var months: Int {
        switch self {
        case .oneMonth: return 1
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        }
    }
}

/// Gruppiert FuelEntry-Einträge anhand gerundeter GPS-Werte.
struct FuelGroup: Identifiable {
    let id: String  // z. B. "51.1221,6.9248"
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let totalCost: Double
}

/// Einzelner Gas- oder Service-Pin auf der Karte.
struct MapPin: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let kind: PinKind

    enum PinKind {
        case gas
        case service
    }
}

struct FuelMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager

    // MARK: - State

    @State private var selectedPeriod: FilterPeriod = .oneMonth
    @State private var fuelEntries: [FuelEntry] = []
    @State private var cachedFuelGroups: [FuelGroup] = []
    @State private var gasEntries: [GasEntry] = []
    @State private var serviceEntries: [ServiceEntry] = []
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedGroupID: String? = nil

    // Filter toggles
    @State private var showFuel: Bool = true
    @State private var showGas: Bool = true
    @State private var showService: Bool = true

    // Max visible fuel groups before showing a warning
    private let maxVisibleGroups = 500

    // MARK: - Computed

    private var visibleFuelGroups: [FuelGroup] {
        showFuel ? Array(cachedFuelGroups.prefix(maxVisibleGroups)) : []
    }

    private var tooManyGroups: Bool {
        showFuel && cachedFuelGroups.count > maxVisibleGroups
    }

    private var gasPins: [MapPin] {
        guard showGas else { return [] }
        return gasEntries.compactMap { entry in
            guard entry.latitude != 0 || entry.longitude != 0 else { return nil }
            return MapPin(
                id: entry.id,
                coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
                kind: .gas
            )
        }
    }

    private var servicePins: [MapPin] {
        guard showService else { return [] }
        return serviceEntries.compactMap { entry in
            guard entry.latitude != 0 || entry.longitude != 0 else { return nil }
            return MapPin(
                id: entry.id,
                coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
                kind: .service
            )
        }
    }

    private var allAnnotations: [MapPin] {
        gasPins + servicePins
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Period picker
                Picker("Zeitraum", selection: $selectedPeriod) {
                    ForEach(FilterPeriod.allCases) { period in
                        Text(period.rawValue)
                            .tag(period)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: selectedPeriod) { _ in loadEntries() }

                // Filter toggles
                HStack(spacing: 16) {
                    Toggle(isOn: $showFuel) {
                        Label("Tankstellen", systemImage: "fuelpump.fill")
                            .foregroundColor(.red)
                    }
                    .toggleStyle(.button)
                    .tint(.red)

                    Toggle(isOn: $showGas) {
                        Label("Gas", systemImage: "flame.fill")
                            .foregroundColor(.green)
                    }
                    .toggleStyle(.button)
                    .tint(.green)

                    Toggle(isOn: $showService) {
                        Label("Ver-/Entsorgung", systemImage: "drop.fill")
                            .foregroundColor(.blue)
                    }
                    .toggleStyle(.button)
                    .tint(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Too-many-groups warning
                if tooManyGroups {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Zu viele Einträge – verwende den Zeitraumfilter")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Map
                mapView
                    .edgesIgnoringSafeArea(.bottom)
            }
            .navigationTitle("Karte")
            .onAppear {
                updateRegion()
                loadEntries()
            }
        }
    }

    // MARK: - Map View

    @ViewBuilder
    private var mapView: some View {
        let hasContent = !visibleFuelGroups.isEmpty || !allAnnotations.isEmpty

        if hasContent {
            // Combined annotation list: fuel groups + gas/service pins
            // We use two overlapping Map layers to keep type safety simple.
            ZStack {
                Map(coordinateRegion: $region, annotationItems: visibleFuelGroups) { group in
                    MapAnnotation(coordinate: group.coordinate) {
                        fuelAnnotationView(for: group)
                    }
                }

                // Overlay gas & service pins using a transparent map on top
                if !allAnnotations.isEmpty {
                    Map(coordinateRegion: $region, annotationItems: allAnnotations) { pin in
                        MapAnnotation(coordinate: pin.coordinate) {
                            pinAnnotationView(for: pin)
                        }
                    }
                    .allowsHitTesting(true)
                    .background(Color.clear)
                    .opacity(1)
                }
            }
        } else {
            if let userLocation = locationManager.lastLocation {
                let userAnnotation = IdentifiableCoordinate(coordinate: userLocation.coordinate)
                Map(coordinateRegion: $region, annotationItems: [userAnnotation]) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            } else {
                Map(coordinateRegion: $region)
            }
        }
    }

    // MARK: - Annotation Views

    @ViewBuilder
    private func fuelAnnotationView(for group: FuelGroup) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "fuelpump.fill")
                .foregroundColor(selectedGroupID == group.id ? .blue : .red)
                .font(.title3)
            if group.count > 1 {
                Text("\(group.count)")
                    .font(.caption2)
                    .bold()
                    .padding(3)
                    .background(Color.white.opacity(0.8))
                    .clipShape(Circle())
            }
        }
        .onTapGesture {
            selectedGroupID = selectedGroupID == group.id ? nil : group.id
        }
    }

    @ViewBuilder
    private func pinAnnotationView(for pin: MapPin) -> some View {
        switch pin.kind {
        case .gas:
            Image(systemName: "flame.fill")
                .foregroundColor(.green)
                .font(.title3)
        case .service:
            Image(systemName: "drop.fill")
                .foregroundColor(.blue)
                .font(.title3)
        }
    }

    // MARK: - Data Loading

    private func countEntries(for period: FilterPeriod) -> Int {
        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .month, value: -period.months, to: Date()) else { return 0 }
        let now = Date()
        let predicate = NSPredicate(
            format: "date >= %@ AND date <= %@ AND latitude != 0 AND longitude != 0",
            startDate as NSDate, now as NSDate
        )
        let request: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
        request.predicate = predicate
        do {
            return try viewContext.count(for: request)
        } catch {
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
        let datePredicate = NSPredicate(
            format: "date >= %@ AND date <= %@ AND latitude != 0 AND longitude != 0",
            startDate as NSDate, now as NSDate
        )

        // FuelEntry
        let fuelRequest: NSFetchRequest<FuelEntry> = NSFetchRequest(entityName: "FuelEntry")
        fuelRequest.predicate = datePredicate
        fuelRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        // GasEntry
        let gasRequest: NSFetchRequest<GasEntry> = NSFetchRequest(entityName: "GasEntry")
        gasRequest.predicate = datePredicate
        gasRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        // ServiceEntry
        let serviceRequest: NSFetchRequest<ServiceEntry> = NSFetchRequest(entityName: "ServiceEntry")
        serviceRequest.predicate = datePredicate
        serviceRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            let fetchedFuel = try viewContext.fetch(fuelRequest)
            fuelEntries = fetchedFuel
            cachedFuelGroups = computeFuelGroups(from: fetchedFuel)

            gasEntries = try viewContext.fetch(gasRequest)
            serviceEntries = try viewContext.fetch(serviceRequest)

            selectedGroupID = nil
        } catch {
            fuelEntries = []
            cachedFuelGroups = []
            gasEntries = []
            serviceEntries = []
        }
    }

    private func computeFuelGroups(from entries: [FuelEntry]) -> [FuelGroup] {
        let grouped = Dictionary(grouping: entries) { entry -> String in
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
