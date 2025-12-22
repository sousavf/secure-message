import Foundation
import Network
import Combine

/**
 * Monitor network connectivity status
 * Detects when device goes online/offline to trigger message sync
 */
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        startMonitoring()
    }

    /**
     * Start monitoring network connectivity
     */
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? false
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)

                // Notify when connection is restored
                if !wasConnected && (self?.isConnected ?? false) {
                    print("Network connection restored")
                    NotificationCenter.default.post(name: .networkConnected, object: nil)
                } else if wasConnected && !(self?.isConnected ?? true) {
                    print("Network connection lost")
                    NotificationCenter.default.post(name: .networkDisconnected, object: nil)
                }
            }
        }

        monitor.start(queue: queue)
    }

    /**
     * Determine connection type
     */
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }

    /**
     * Stop monitoring
     */
    func stopMonitoring() {
        monitor.cancel()
    }

    deinit {
        stopMonitoring()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkConnected = Notification.Name("networkConnected")
    static let networkDisconnected = Notification.Name("networkDisconnected")
}
