import Foundation
import UIKit
import UserNotifications
import CryptoKit

class PushNotificationService {
    static let shared = PushNotificationService()

    private let apiService = APIService.shared

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

    /// Register APNs token with backend
    func registerToken(_ apnsToken: String) async {
        let deviceId = persistentDeviceID

        print("[DEBUG] PushNotificationService - Registering APNs token for device: \(deviceId)")
        showAlert("Debug", "Registering token for device: \(deviceId.prefix(8))...")

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
                    showAlert("Success", "APNs token registered!")
                } else {
                    let msg = "Failed to register token, status: \(httpResponse.statusCode)"
                    print("[ERROR] PushNotificationService - \(msg)")
                    showAlert("Error", msg)
                }
            }
        } catch {
            let msg = "Failed to register APNs token: \(error)"
            print("[ERROR] PushNotificationService - \(msg)")
            showAlert("Error", msg)
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

            // Notify observers to refresh messages
            NotificationCenter.default.post(
                name: PushNotificationService.newMessageReceivedNotification,
                object: nil,
                userInfo: ["conversationHash": conversationHash]
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
    /// Must match the backend SHA256 implementation
    private func hashConversationId(_ id: UUID) -> String {
        let data = id.uuidString.data(using: .utf8)!
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
