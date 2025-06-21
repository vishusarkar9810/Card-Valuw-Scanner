import SwiftUI
import StoreKit

class SubscriptionViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var isPremium = false
    @Published var isTrialEnabled = false
    @Published var isLoading = false
    @Published var selectedPlan: SubscriptionPlan = .yearly
    
    // Subscription options
    let yearlyPlanPrice = "₹2,499.00"
    let yearlyPlanOriginalPrice = "₹41,548.00"
    let yearlyPlanSavings = "93%"
    let trialPrice = "₹799.00"
    let trialDuration = "3-Day"
    
    // MARK: - Subscription Plans
    
    enum SubscriptionPlan {
        case yearly
        case trial
    }
    
    // MARK: - Methods
    
    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
    }
    
    func toggleTrialEnabled() {
        isTrialEnabled.toggle()
    }
    
    func startFreeTrial() {
        isLoading = true
        selectPlan(.trial)
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.isTrialEnabled = true
        }
    }
    
    func purchaseYearlyPlan() {
        isLoading = true
        selectPlan(.yearly)
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.isPremium = true
        }
    }
    
    func restorePurchases() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
        }
    }
} 