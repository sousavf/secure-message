import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var products: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    // Product identifiers - these should match your App Store Connect configuration
    private let subscriptionProductIDs = [
        "pt.sousavf.Safe-Whisper.premium.monthly",
        "pt.sousavf.Safe-Whisper.premium.yearly"
    ]
    
    enum SubscriptionStatus {
        case free
        case premium
        case unknown
        
        var displayName: String {
            switch self {
            case .free:
                return "Free"
            case .premium:
                return "Premium"
            case .unknown:
                return "Unknown"
            }
        }
    }
    
    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
        Task {
            await updateSubscriptionStatus()
            await loadProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: subscriptionProductIDs)
            self.products = products.sorted { product1, product2 in
                // Sort by price, lowest first
                return product1.price < product2.price
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
            return nil
        default:
            return nil
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        
        // Check for active subscriptions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if subscriptionProductIDs.contains(transaction.productID) {
                    hasActiveSubscription = true
                    break
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        subscriptionStatus = hasActiveSubscription ? .premium : .free
        
        // Sync with backend
        await syncSubscriptionWithBackend()
    }
    
    private func syncSubscriptionWithBackend() async {
        guard let deviceId = await DeviceIdentifierManager.shared.getDeviceId() else {
            print("No device ID available for subscription sync")
            return
        }
        
        if subscriptionStatus == .premium {
            // Get the latest receipt and verify with backend
            if let receiptData = try? await getAppStoreReceiptData() {
                await APIService.shared.verifySubscription(deviceId: deviceId, receiptData: receiptData)
            }
        } else {
            // Check subscription status with backend
            await APIService.shared.checkSubscriptionStatus(deviceId: deviceId)
        }
    }
    
    // MARK: - Private Methods
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func getAppStoreReceiptData() async throws -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            throw StoreError.receiptNotFound
        }
        
        let receiptData = try Data(contentsOf: receiptURL)
        return receiptData.base64EncodedString()
    }
}

enum StoreError: Error, LocalizedError {
    case failedVerification
    case receiptNotFound
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction failed verification"
        case .receiptNotFound:
            return "App Store receipt not found"
        }
    }
}

// MARK: - Device Identifier Manager

class DeviceIdentifierManager {
    static let shared = DeviceIdentifierManager()
    
    private let deviceIdKey = "DeviceIdentifier"
    
    private init() {}
    
    func getDeviceId() async -> String? {
        if let savedDeviceId = UserDefaults.standard.string(forKey: deviceIdKey) {
            return savedDeviceId
        }
        
        // Generate new device ID
        let newDeviceId = UUID().uuidString
        UserDefaults.standard.set(newDeviceId, forKey: deviceIdKey)
        return newDeviceId
    }
}