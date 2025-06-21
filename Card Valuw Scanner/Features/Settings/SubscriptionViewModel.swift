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
    
    // Hard-coded values for UI display (these would ideally come from the server)
    let yearlyPlanOriginalPrice = "₹41,548.00"
    let yearlyPlanSavings = "93%"
    
    var trialPrice: String {
        subscriptionService.formattedPrice(for: subscriptionService.trialSubscription)
    }
    
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