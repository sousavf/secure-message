import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProduct: Product?
    @State private var showingPurchaseAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if subscriptionManager.subscriptionStatus == .premium {
                        premiumActiveSection
                    } else {
                        featuresSection
                        subscriptionOptions
                    }
                    
                    if subscriptionManager.subscriptionStatus == .free {
                        restoreSection
                    }
                }
                .padding()
            }
            .navigationTitle("Premium Features")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Purchase Result", isPresented: $showingPurchaseAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.updateSubscriptionStatus()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Safe Whisper Premium")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Unlock premium features for enhanced messaging")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    private var premiumActiveSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text("Premium Active")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Text("You have access to all premium features including 10MB image sharing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.headline)
                .fontWeight(.semibold)
            
            FeatureRow(
                icon: "photo.fill",
                title: "10MB Image Sharing",
                description: "Send high-quality images up to 10MB"
            )
            
            FeatureRow(
                icon: "bolt.fill",
                title: "Priority Support",
                description: "Get faster response to your questions"
            )
            
            FeatureRow(
                icon: "shield.fill",
                title: "Enhanced Security",
                description: "Additional security features for premium users"
            )
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)
                .fontWeight(.semibold)
            
            if subscriptionManager.isLoading {
                ProgressView("Loading plans...")
                    .frame(height: 100)
            } else if subscriptionManager.products.isEmpty {
                Text("No subscription plans available")
                    .foregroundColor(.secondary)
                    .frame(height: 100)
            } else {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    SubscriptionOptionRow(
                        product: product,
                        isSelected: selectedProduct?.id == product.id,
                        action: {
                            selectedProduct = product
                            Task {
                                await purchaseProduct(product)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var restoreSection: some View {
        VStack {
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            
            Text("Already purchased? Restore your subscription")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private func purchaseProduct(_ product: Product) async {
        do {
            let transaction = try await subscriptionManager.purchase(product)
            if transaction != nil {
                alertMessage = "Purchase successful! Premium features are now active."
            } else {
                alertMessage = "Purchase was cancelled."
            }
        } catch {
            alertMessage = "Purchase failed: \(error.localizedDescription)"
        }
        showingPurchaseAlert = true
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SubscriptionOptionRow: View {
    let product: Product
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if product.subscription?.subscriptionPeriod.unit == .month {
                        Text("per month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if product.subscription?.subscriptionPeriod.unit == .year {
                        Text("per year")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SubscriptionView()
}