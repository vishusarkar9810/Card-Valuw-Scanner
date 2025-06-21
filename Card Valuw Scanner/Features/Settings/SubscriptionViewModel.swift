import SwiftUI
import StoreKit
import Observation

@Observable final class SubscriptionViewModel {
    // MARK: - Properties
    
    private let subscriptionService: SubscriptionService
    
    var isPremium: Bool {
        subscriptionService.isPremium
    }
    
    var isTrialEnabled = false {
        didSet {
            // Keep the selected plan in sync with the trial toggle
            if isTrialEnabled && selectedPlan != .trial {
                selectedPlan = .trial
            } else if !isTrialEnabled && selectedPlan != .yearly {
                selectedPlan = .yearly
            }
        }
    }
    
    var isLoading: Bool {
        subscriptionService.isLoading
    }
    
    var errorMessage: String? {
        subscriptionService.errorMessage
    }
    
    var selectedPlan: SubscriptionPlan = .yearly {
        didSet {
            // Keep the trial toggle in sync with the selected plan
            isTrialEnabled = (selectedPlan == .trial)
        }
    }
    
    // Subscription options
    var yearlyPlanPrice: String {
        subscriptionService.formattedPrice(for: subscriptionService.yearlySubscription)
    }
    
    // Calculate original price based on weekly subscription price * 52 weeks
    var yearlyPlanOriginalPrice: String {
        guard let weeklyPrice = subscriptionService.rawPrice(for: subscriptionService.trialSubscription) else {
            return "N/A"
        }
        
        // Calculate what it would cost to pay weekly for a year
        let annualCost = weeklyPrice * 52
        
        // Use the formatPrice method to ensure consistent currency formatting
        return subscriptionService.formatPrice(annualCost, using: subscriptionService.trialSubscription)
    }
    
    // Calculate savings percentage dynamically
    var yearlyPlanSavings: String {
        guard let yearlyPrice = subscriptionService.rawPrice(for: subscriptionService.yearlySubscription),
              let weeklyPrice = subscriptionService.rawPrice(for: subscriptionService.trialSubscription) else {
            return "N/A"
        }
        
        let annualCostIfWeekly = weeklyPrice * 52
        let savings = (annualCostIfWeekly - yearlyPrice) / annualCostIfWeekly * 100
        
        // Convert to Double for rounding, then to Int
        let savingsDouble = NSDecimalNumber(decimal: savings).doubleValue
        let roundedSavings = Int(savingsDouble.rounded())
        
        return "\(roundedSavings)%"
    }
    
    var trialPrice: String {
        subscriptionService.formattedPrice(for: subscriptionService.trialSubscription)
    }
    
    // This should return "3-Day" to match App Store Connect configuration
    var trialDuration: String {
        subscriptionService.formattedSubscriptionPeriod(for: subscriptionService.trialSubscription)
    }
    
    // MARK: - Subscription Plans
    
    enum SubscriptionPlan {
        case yearly
        case trial
    }
    
    // MARK: - Initialization
    
    init(subscriptionService: SubscriptionService = SubscriptionService()) {
        self.subscriptionService = subscriptionService
    }
    
    // MARK: - Methods
    
    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }
    
    func toggleTrialEnabled() {
        isTrialEnabled.toggle()
    }
    
    func startFreeTrial() async {
        await subscriptionService.startFreeTrial()
    }
    
    func purchaseYearlyPlan() async {
        await subscriptionService.purchaseYearlyPlan()
    }
    
    func restorePurchases() async {
        await subscriptionService.restorePurchases()
    }
    
    // MARK: - Feature Access
    
    func canAccessPremiumFeature(_ feature: PremiumFeature) -> Bool {
        return subscriptionService.canAccessPremiumFeature(feature)
    }
} 