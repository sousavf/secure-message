import Foundation
import UIKit
import UserNotifications
import CryptoKit

class PushNotificationService {
    static let shared = PushNotificationService()

    private let apiService = APIService.shared
    private let tokenRefreshInterval: TimeInterval = 24 * 60 * 60  // 24 hours
    private let lastTokenRegistrationKey = "lastAPNsTokenRegistration"
    private let lastRegisteredTokenKey = "lastRegisteredAPNsToken"

    // Notification name for when new messages arrive
    static let newMessageReceivedNotification = NSNotification.Name("newMessageReceived")

    // Get the persistent device ID (same one used throughout the app)
    var persistentDeviceID: String {
        let defaults = UserDefaults.standard
        let deviceIdKey = "deviceId"  // Same key as MainView uses!

        // Try to get existing ID
        if let existingID = defaults.string(forKey: deviceIdKey) {
            return existingID
        }

        // Create new ID if doesn't exist (MainView should have already created this)
        let newID = UUID().uuidString
        defaults.set(newID, forKey: deviceIdKey)
        return newID
    }

    // MARK: - Public Methods

    /// Check if APNs token registration needs refresh (called on app launch)
    func refreshTokenIfNeeded() async {
        let defaults = UserDefaults.standard
        let lastRegistration = defaults.double(forKey: lastTokenRegistrationKey)
        let timeSinceLastRegistration = Date().timeIntervalSince1970 - lastRegistration

        // Re-register if more than 24 hours have passed
        if timeSinceLastRegistration > tokenRefreshInterval {
            print("[DEBUG] PushNotificationService - Token registration expired, requesting new token")
            // Request APNs to generate a new token (or refresh the existing one)
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            print("[DEBUG] PushNotificationService - Token is fresh, no refresh needed")
        }
    }

    /// Force re-register APNs token (called when app comes to foreground)
    /// This ensures the backend always has a valid token even if app was backgrounded
    func forceTokenRefresh() async {
        print("[DEBUG] PushNotificationService - Force refreshing APNs token")
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Register APNs token with backend
    func registerToken(_ apnsToken: String) async {
        let deviceId = persistentDeviceID
        let defaults = UserDefaults.standard

        // Check if token has changed
        let lastToken = defaults.string(forKey: lastRegisteredTokenKey)
        if lastToken == apnsToken {
            print("[DEBUG] PushNotificationService - Token unchanged, skipping registration")
            return
        }

        print("[DEBUG] PushNotificationService - Registering APNs token for device: \(deviceId)")

        do {
            let request = RegisterDeviceTokenRequest(apnsToken: apnsToken)

            // Create request manually to add X-Device-ID header
            guard let url = URL(string: "https://privileged.stratholme.eu/api/devices/token") else {
                print("[ERROR] PushNotificationService - Invalid URL")
                return
            }

            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")

            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)

            let (_, response) = try await URLSession.shared.data(for: urlRequest)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    print("[DEBUG] PushNotificationService - APNs token registered successfully")
                    // Save registration timestamp and token for future checks
                    defaults.set(Date().timeIntervalSince1970, forKey: lastTokenRegistrationKey)
                    defaults.set(apnsToken, forKey: lastRegisteredTokenKey)
                } else {
                    let msg = "Failed to register token, status: \(httpResponse.statusCode)"
                    print("[ERROR] PushNotificationService - \(msg)")
                }
            }
        } catch {
            let msg = "Failed to register APNs token: \(error)"
            print("[ERROR] PushNotificationService - \(msg)")
        }
    }

    private func showAlert(_ title: String, _ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))

            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }

    /// Request push notification permissions
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            if granted {
                print("[DEBUG] PushNotificationService - User granted notification permission")
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("[DEBUG] PushNotificationService - User denied notification permission")
            }

            return granted
        } catch {
            print("[ERROR] PushNotificationService - Failed to request notification authorization: \(error)")
            return false
        }
    }

    /// Handle silent push notification (content-available)
    /// This is called when a silent push arrives while app is in background
    func handleSilentPush(userInfo: [AnyHashable: Any]) {
        print("[DEBUG] PushNotificationService - Handling silent push")

        // Extract conversation hash from push payload
        if let conversationHash = userInfo["c"] as? String {
            print("[DEBUG] PushNotificationService - Received push for conversation hash: \(conversationHash)")

            // Extract notification type if present
            var notificationInfo: [String: Any] = ["conversationHash": conversationHash]
            if let notificationType = userInfo["type"] as? String {
                print("[DEBUG] PushNotificationService - Notification type: \(notificationType)")
                notificationInfo["type"] = notificationType
            }

            // Notify observers to refresh messages or handle deletion/expiration
            NotificationCenter.default.post(
                name: PushNotificationService.newMessageReceivedNotification,
                object: nil,
                userInfo: notificationInfo
            )
        }
    }

    /// Check if notifications are enabled for the app
    func isNotificationEnabled() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let isEnabled = settings.authorizationStatus == .authorized
        print("[DEBUG] PushNotificationService - Notifications enabled: \(isEnabled)")
        return isEnabled
    }

    // MARK: - Private Methods

    /// Hash conversation ID to match backend implementation
    /// Must use lowercase UUID string to match Java's UUID.toString() format
    private func hashConversationId(_ id: UUID) -> String {
        let lowercaseUUID = id.uuidString.lowercased()
        let data = lowercaseUUID.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        return String(hashString.prefix(32))
    }
}

// MARK: - Request/Response Models

struct RegisterDeviceTokenRequest: Codable {
    let apnsToken: String
}

struct DeviceTokenResponse: Codable {
    let tokenId: String
    let deviceId: String
    let message: String
}
