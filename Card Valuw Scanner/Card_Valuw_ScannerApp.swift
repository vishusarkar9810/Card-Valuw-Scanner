//
//  Card_Valuw_ScannerApp.swift
//  Card Valuw Scanner
//
//  Created by Vishwajeet Sarkar on 16/06/25.
//

import SwiftUI
import SwiftData
import StoreKit

@main
struct Card_Valuw_ScannerApp: App {
    // Set up the model container for SwiftData
    var modelContainer: ModelContainer
    
    // Read dark mode preference from AppStorage
    @AppStorage("darkMode") private var darkMode = false
    
    // Shared subscription service
    @State private var subscriptionService = SubscriptionService()
    
    // Onboarding manager
    @StateObject private var onboardingManager = OnboardingManager()
    
    // App review service
    @StateObject private var appReviewService = AppReviewService()
    
    // Scene phase for tracking app state
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        do {
            // Create a model container for CardEntity and CollectionEntity
            let schema = Schema([CardEntity.self, CollectionEntity.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingManager.hasCompletedOnboarding {
            MainTabView()
                .preferredColorScheme(darkMode ? .dark : .light)
                .environment(subscriptionService)
                .environment(appReviewService)
                .task {
                    // Check if we should request a review
                    appReviewService.requestReviewIfAppropriate()
                }
            } else {
                OnboardingView(isOnboardingCompleted: $onboardingManager.hasCompletedOnboarding)
                    .preferredColorScheme(.dark) // Onboarding looks best in dark mode
                    .ignoresSafeArea(.keyboard) // Only ignore keyboard, not safe areas for notch/home indicator
                    .environment(appReviewService)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // Update subscription status when app becomes active
                Task {
                    await subscriptionService.updateSubscriptionStatus()
                }
            }
        }
    }
}
