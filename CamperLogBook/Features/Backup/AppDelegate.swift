import UIKit
import UserNotifications
import CoreData
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let autoBackupTaskIdentifier = "de.vanityontour.camperlogbook.autobackup"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Registriere für Benachrichtigungen
        UNUserNotificationCenter.current().delegate = self
        
        registerBackgroundTasks()
        scheduleAutomaticBackupIfNeeded()
        
        // Fallback für iOS 12 und älter
        if #unavailable(iOS 13.0) {
            application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        }
        
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
    
    private func registerBackgroundTasks() {
        guard #available(iOS 13.0, *) else { return }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: autoBackupTaskIdentifier, using: nil) { task in
            self.handleAutoBackup(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleAutomaticBackupIfNeeded() {
        guard #available(iOS 13.0, *),
              UserDefaults.standard.bool(forKey: "automaticBackupsEnabled") else { return }
        
        let request = BGAppRefreshTaskRequest(identifier: autoBackupTaskIdentifier)
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Konnte Hintergrund-Backup nicht planen: \(error.localizedDescription)")
        }
    }
    
    @available(iOS 13.0, *)
    private func handleAutoBackup(task: BGAppRefreshTask) {
        scheduleAutomaticBackupIfNeeded()
        
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        performAutomaticBackup { success in
            task.setTaskCompleted(success: success)
        }
    }
}
