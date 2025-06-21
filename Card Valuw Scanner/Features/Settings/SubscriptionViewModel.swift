import SwiftUI
import StoreKit

class SubscriptionViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var isPremium = false
    @Published var isTrialEnabled = false
    @Published var isLoading = false
    
    // Subscription options
    let yearlyPlanPrice = "₹2,499.00"
    let yearlyPlanOriginalPrice = "₹41,548.00"
    let yearlyPlanSavings = "93%"
    let trialPrice = "₹799.00"
    let trialDuration = "3-Day"
    
    // MARK: - Methods
    
    func startFreeTrial() {
        isLoading = true
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.isTrialEnabled = true
        }
    }
    
    func purchaseYearlyPlan() {
        isLoading = true
        
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