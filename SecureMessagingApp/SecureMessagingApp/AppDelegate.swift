import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - UIApplicationDelegate Methods

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[DEBUG] AppDelegate - Application did finish launching")

        // Set push notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request push notification permissions and register for remote notifications
        Task {
            print("[DEBUG] AppDelegate - Requesting authorization")
            let authorized = await PushNotificationService.shared.requestAuthorization()
            print("[DEBUG] AppDelegate - Authorization result: \(authorized)")

            // Add a small delay before requesting remote notifications
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            print("[DEBUG] AppDelegate - Requesting remote notifications")
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
                print("[DEBUG] AppDelegate - registerForRemoteNotifications() called")
            }
        }

        return true
    }

    /// Called when device successfully registers for remote notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[DEBUG] AppDelegate - Registered for remote notifications, token: \(token.prefix(16))...")
        print("[DEBUG] AppDelegate - Token length: \(token.count)")

        // Register the token with our backend
        print("[DEBUG] AppDelegate - About to register token with backend")
        Task {
            print("[DEBUG] AppDelegate - Inside Task, calling registerToken")
            await PushNotificationService.shared.registerToken(token)
            print("[DEBUG] AppDelegate - registerToken completed")
        }
    }

    /// Called when device fails to register for remote notifications
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[ERROR] AppDelegate - Failed to register for remote notifications: \(error)")
    }

    /// Handle remote notification when app is in background or foreground
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        print("[DEBUG] AppDelegate - Received remote notification")

        // Check if this is a silent notification (content-available)
        let aps = userInfo["aps"] as? [String: Any]
        let contentAvailable = aps?["content-available"] as? Int == 1

        if contentAvailable {
            // This is a silent push notification
            print("[DEBUG] AppDelegate - Silent push received")
            PushNotificationService.shared.handleSilentPush(userInfo: userInfo)
            completionHandler(.newData)
        } else {
            // Regular notification - already handled by UNUserNotificationCenter delegate
            completionHandler(.noData)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate Methods

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("[DEBUG] AppDelegate - Notification received while in foreground")

        let userInfo = notification.request.content.userInfo

        // For security, we don't show the notification UI (silent)
        // Instead, we trigger a refresh in the background
        PushNotificationService.shared.handleSilentPush(userInfo: userInfo)

        // Don't show notification badge/alert for silent pushes
        completionHandler([])
    }

    /// Handle user tapping on notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("[DEBUG] AppDelegate - User tapped on notification")

        let userInfo = response.notification.request.content.userInfo
        PushNotificationService.shared.handleSilentPush(userInfo: userInfo)

        completionHandler()
    }
}
