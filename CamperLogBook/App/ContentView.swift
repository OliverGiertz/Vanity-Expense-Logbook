import SwiftUI
import CoreData

struct ContentView: View {
    @AppStorage("showStartInfo") var showStartInfo: Bool = true
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: MaintenanceInterval.entity(),
        sortDescriptors: []
    ) private var allIntervals: FetchedResults<MaintenanceInterval>

    @FetchRequest(
        entity: FuelEntry.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \FuelEntry.date, ascending: false)]
    ) private var lastFuel: FetchedResults<FuelEntry>

    private var currentKm: Int64 { lastFuel.first?.currentKm ?? 0 }

    private var dueCount: Int {
        allIntervals.filter { interval in
            if interval.intervalKm > 0 {
                let remaining = (interval.lastServiceKm + interval.intervalKm) - currentKm
                if remaining <= 0 { return true }
            }
            if interval.intervalMonths > 0, let last = interval.lastServiceDate {
                let cal = Calendar.current
                if let due = cal.date(byAdding: .month, value: Int(interval.intervalMonths), to: last) {
                    if due <= Date() { return true }
                }
            }
            return false
        }.count
    }

    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("Übersicht", systemImage: "list.bullet")
                }
            EntryView()
                .tabItem {
                    Label("Eintrag", systemImage: "plus.circle")
                }
            ExpenseListView()
                .tabItem {
                    Label("Ausgaben", systemImage: "list.bullet.rectangle")
                }
            AnalysisView()
                .tabItem {
                    Label("Auswertung", systemImage: "chart.bar")
                }
            MaintenanceView()
                .tabItem {
                    Label("Wartung", systemImage: "wrench.and.screwdriver.fill")
                }
                .badge(dueCount > 0 ? dueCount : 0)
            FuelMapView()
                .tabItem {
                    Label("Karte", systemImage: "map")
                }
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
            #if DEBUG
            NavigationView {
                DebugView()
            }
            .tabItem {
                Label("Debug", systemImage: "ladybug.fill")
            }
            #endif
        }
        .fullScreenCover(isPresented: $showStartInfo) {
            StartInfoView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
