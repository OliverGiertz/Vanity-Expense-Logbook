import UIKit
import UserNotifications
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Registriere für Benachrichtigungen
        UNUserNotificationCenter.current().delegate = self
        
        // Registriere für Background-Refresh
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        return true
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Prüfen, ob automatisches Backup aktiviert ist
        if UserDefaults.standard.bool(forKey: "automaticBackupsEnabled") {
            performAutomaticBackup { success in
                completionHandler(success ? .newData : .failed)
            }
        } else {
            completionHandler(.noData)
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Erlaube Benachrichtigungen auch, wenn die App im Vordergrund ist
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Wenn die Benachrichtigung ein automatisches Backup auslösen soll
        if let actionType = userInfo["actionType"] as? String, actionType == "autoBackup" {
            performAutomaticBackup { _ in
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
    
    private func performAutomaticBackup(completion: @escaping (Bool) -> Void) {
        let context = PersistenceController.shared.container.viewContext
        let backupManager = CloudBackupManager.shared
        backupManager.connect(to: context)
        backupManager.createBackup { success, errorMessage in
            if success {
                print("Automatisches Backup erfolgreich erstellt")
                completion(true)
            } else {
                print("Automatisches Backup fehlgeschlagen: \(errorMessage ?? "Unbekannter Fehler")")
                completion(false)
            }
        }
    }
}
