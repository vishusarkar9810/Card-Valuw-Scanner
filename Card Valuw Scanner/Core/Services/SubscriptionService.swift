import StoreKit
import SwiftUI

/// A service that manages in-app purchases and subscriptions using StoreKit 2
@Observable final class SubscriptionService {
    // MARK: - Properties
    
    // Product identifiers
    private let yearlySubscriptionID = "com.cardvaluescanner.yearly"
    private let trialSubscriptionID = "com.cardvaluescanner.trial"
    
    // Available products
    private(set) var yearlySubscription: Product?
    private(set) var trialSubscription: Product?
    
    // Subscription status
    private(set) var isPremium = false
    private(set) var purchasedSubscriptions: [Product.SubscriptionInfo.Status] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    // Transaction listener
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()
        
        // Load products
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Product Loading
    
    @MainActor
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: [yearlySubscriptionID, trialSubscriptionID])
            
            // Store products
            for product in products {
                switch product.id {
                case yearlySubscriptionID:
                    yearlySubscription = product
                case trialSubscriptionID:
                    trialSubscription = product
                default:
                    break
                }
            }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Transaction Handling
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Update the user's subscription status
                    await self.updateSubscriptionStatus()
                    
                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    // StoreKit has a receipt it can read but it failed verification.
                    print("Transaction failed verification: \(error)")
                }
            }
        }
    }
    
    // MARK: - Purchase Methods
    
    @MainActor
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    await updateSubscriptionStatus()
                    await transaction.finish()
                    isLoading = false
                } catch {
                    errorMessage = "Transaction failed verification: \(error.localizedDescription)"
                    isLoading = false
                }
            case .userCancelled:
                errorMessage = nil
                isLoading = false
            case .pending:
                errorMessage = "Purchase is pending approval."
                isLoading = false
            @unknown default:
                errorMessage = "Unknown purchase result."
                isLoading = false
            }
        } catch {
            errorMessage = "Failed to purchase: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    @MainActor
    func purchaseYearlyPlan() async {
        guard let product = yearlySubscription else {
            errorMessage = "Yearly subscription product not available."
            return
        }
        
        await purchase(product)
    }
    
    @MainActor
    func startFreeTrial() async {
        guard let product = trialSubscription else {
            errorMessage = "Trial subscription product not available."
            return
        }
        
        await purchase(product)
    }
    
    @MainActor
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            isLoading = false
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Subscription Status
    
    @MainActor
    func updateSubscriptionStatus() async {
        // Get the subscription products if they're not loaded yet
        if yearlySubscription == nil || trialSubscription == nil {
            await loadProducts()
        }
        
        // Check for active subscriptions
        var hasActiveSubscription = false
        
        // Check for active subscriptions using Transaction.currentEntitlements
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // If the transaction has not been revoked (refunded, etc.)
            if transaction.revocationDate == nil && 
               (transaction.productID == yearlySubscriptionID || 
                transaction.productID == trialSubscriptionID) {
                hasActiveSubscription = true
                break
            }
        }
        
        // Update the premium status
        isPremium = hasActiveSubscription
        
        // We already determined subscription status from Transaction.currentEntitlements
    }
    
    // MARK: - Helper Methods
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Subscription Information
    
    func formattedPrice(for product: Product?) -> String {
        guard let product = product else { return "N/A" }
        return product.displayPrice
    }
    
    func rawPrice(for product: Product?) -> Decimal? {
        guard let product = product else { return nil }
        return product.price
    }
    
    func currencySymbol(for product: Product?) -> String {
        guard let product = product else {
            // Default to user's locale currency symbol if product is not available
            return Locale.current.currencySymbol ?? "$"
        }
        
        // Extract currency symbol from the product's formatted price
        // This ensures we use the same currency symbol as shown in the App Store
        let priceString = product.displayPrice
        
        // Find the first character that's not a digit, space, or period
        // This is likely the currency symbol
        if let currencySymbol = priceString.first(where: { !$0.isNumber && $0 != "." && $0 != " " && $0 != "," }) {
            return String(currencySymbol)
        }
        
        // Fallback to user's locale currency symbol
        return Locale.current.currencySymbol ?? "$"
    }
    
    func formattedSubscriptionPeriod(for product: Product?) -> String {
        guard let product = product,
              let subscription = product.subscription else {
            return ""
        }
        
        // Special handling for trial subscription
        if product.id == trialSubscriptionID {
            // Hardcode to 3-Day to match App Store Connect configuration
            return "3-Day"
        }
        
        switch subscription.subscriptionPeriod.unit {
        case .day:
            return "\(subscription.subscriptionPeriod.value)-Day"
        case .week:
            return "\(subscription.subscriptionPeriod.value) week\(subscription.subscriptionPeriod.value > 1 ? "s" : "")"
        case .month:
            return "\(subscription.subscriptionPeriod.value) month\(subscription.subscriptionPeriod.value > 1 ? "s" : "")"
        case .year:
            return "\(subscription.subscriptionPeriod.value) year\(subscription.subscriptionPeriod.value > 1 ? "s" : "")"
        @unknown default:
            return "Unknown period"
        }
    }
    
    func hasActiveSubscription() -> Bool {
        return isPremium
    }
    
    func formatPrice(_ price: Decimal, using referenceProduct: Product?) -> String {
        guard let product = referenceProduct else {
            // Default formatting if no product is available
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencySymbol = Locale.current.currencySymbol ?? "$"
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "N/A"
        }
        
        // Get the currency symbol from the product
        let currencySymbol = self.currencySymbol(for: product)
        
        // Format as currency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: NSDecimalNumber(decimal: price)) ?? "N/A"
    }
}

// MARK: - Errors

enum StoreError: Error {
    case failedVerification
    case productNotFound
    case purchaseFailed
}

// MARK: - Premium Feature Access

extension SubscriptionService {
    // Check if user has access to premium features
    func canAccessPremiumFeature(_ feature: PremiumFeature) -> Bool {
        // If the user is premium, they can access all features
        if isPremium {
            return true
        }
        
        // Otherwise, check if the feature is free
        return feature.isFreeFeature
    }
}

// MARK: - Premium Features

enum PremiumFeature: String, CaseIterable {
    case marketAnalysis = "Indepth market analysis"
    case livePrices = "Live Card prices & sale trends"
    case gradedValuations = "Valuations by grade & edition"
    case unlimitedCollections = "Add unlimited collections"
    
    var isFreeFeature: Bool {
        // Define which features are available in the free tier
        switch self {
        case .marketAnalysis, .livePrices, .gradedValuations:
            return false
        case .unlimitedCollections:
            // Allow users to create up to 1 collection in free tier
            return true
        }
    }
    
    var description: String {
        return self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .marketAnalysis:
            return "chart.line.uptrend.xyaxis.circle.fill"
        case .livePrices:
            return "magnifyingglass.circle.fill"
        case .gradedValuations:
            return "checkmark.circle.fill"
        case .unlimitedCollections:
            return "folder.fill.badge.plus"
        }
    }
}

// MARK: - Environment Key

private struct SubscriptionServiceKey: EnvironmentKey {
    static let defaultValue = SubscriptionService()
}

extension EnvironmentValues {
    var subscriptionService: SubscriptionService {
        get { self[SubscriptionServiceKey.self] }
        set { self[SubscriptionServiceKey.self] = newValue }
    }
} 
