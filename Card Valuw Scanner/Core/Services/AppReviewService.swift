import SwiftUI
import StoreKit

class AppReviewService: ObservableObject {
    @AppStorage("lastReviewRequestDate") private var lastReviewRequestDate: Double = 0
    @AppStorage("appLaunchCount") private var appLaunchCount: Int = 0
    @AppStorage("hasPromptedForReviewDuringOnboarding") private var hasPromptedForReviewDuringOnboarding: Bool = false
    
    // Request review during onboarding
    func requestReviewDuringOnboarding(force: Bool = false) {
        // Only show once during onboarding
        guard force || !hasPromptedForReviewDuringOnboarding else { return }
        
        // Request the review
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            hasPromptedForReviewDuringOnboarding = true
        }
    }
    
    // Request review during normal app usage
    func requestReviewIfAppropriate() {
        appLaunchCount += 1
        
        let currentDate = Date().timeIntervalSince1970
        let daysSinceLastRequest = (currentDate - lastReviewRequestDate) / (60 * 60 * 24)
        
        // Request review if:
        // 1. App has been launched at least 5 times, and
        // 2. Last review request was more than 30 days ago
        if appLaunchCount >= 5 && (daysSinceLastRequest > 30 || lastReviewRequestDate == 0) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                lastReviewRequestDate = currentDate
            }
        }
    }
    
    // Manual review request that can be triggered from settings or after a positive action
    func requestReviewManually() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            lastReviewRequestDate = Date().timeIntervalSince1970
        }
    }
}

// MARK: - Environment Key

private struct AppReviewServiceKey: EnvironmentKey {
    static let defaultValue = AppReviewService()
}

extension EnvironmentValues {
    var appReviewService: AppReviewService {
        get { self[AppReviewServiceKey.self] }
        set { self[AppReviewServiceKey.self] = newValue }
    }
}

extension View {
    func environment(_ appReviewService: AppReviewService) -> some View {
        environment(\.appReviewService, appReviewService)
    }
} 