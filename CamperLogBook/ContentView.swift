import SwiftUI

struct ContentView: View {
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
            AnalysisView()
                .tabItem {
                    Label("Auswertung", systemImage: "chart.bar")
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
