import SwiftUI

@main
struct CamperLogBookApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var locationManager = LocationManager()
    
    // App-Delegate hinzufügen
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Debug mode flag, only true in DEBUG builds
    #if DEBUG
    @State private var isDebugModeEnabled = true
    #else
    @State private var isDebugModeEnabled = false
    #endif

    init() {
        // Achtung: Dieser Aufruf löscht ALLE Daten in allen Entitäten.
        // Verwende ihn nur zu Testzwecken und entferne ihn vor der Veröffentlichung!
        // deleteAllTestData()
        
        // Configure default app appearance
        configureAppAppearance()
    }
    
    private func configureAppAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(locationManager)
                .environment(\.isDebugMode, isDebugModeEnabled)
                .onAppear {
                    // Verbinde CloudBackupManager mit dem CoreData-Kontext
                    CloudBackupManager.shared.connect(to: persistenceController.container.viewContext)
                }
        }
    }
}
