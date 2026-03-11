import SwiftUI

struct ContentView: View {
    @AppStorage("showStartInfo") var showStartInfo: Bool = true
    
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
