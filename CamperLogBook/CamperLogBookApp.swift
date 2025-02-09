import SwiftUI

@main
struct CamperLogBookApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var locationManager = LocationManager()

    init() {
        // Achtung: Dieser Aufruf löscht ALLE Daten in allen Entitäten.
        // Verwende ihn nur zu Testzwecken und entferne ihn vor der Veröffentlichung!
        // deleteAllTestData()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(locationManager)
        }
    }
}
