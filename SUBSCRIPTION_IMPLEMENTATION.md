# Subscription Implementation

This document outlines the subscription implementation for the Pokemon Card Value Scanner app using StoreKit 2.

## Files Created/Modified

1. **SubscriptionService.swift** - Core service that handles StoreKit 2 integration:
   - Product management (loading, purchasing)
   - Transaction handling and verification
   - Subscription status tracking
   - Premium feature access control

2. **SubscriptionViewModel.swift** - Updated to use SubscriptionService:
   - Provides UI-friendly properties and methods
   - Handles user interactions with subscription options
   - Delegates actual purchase operations to SubscriptionService

3. **SubscriptionView.swift** - Updated to work with async operations:
   - Displays subscription options
   - Handles user selection of plans
   - Shows loading states during purchases
   - Displays error messages

4. **CardDetailView.swift** - Updated to gate premium features:
   - Price history chart (Premium)
   - Marketplace deals (Premium)
   - Shows premium feature locked UI for non-subscribers

5. **CollectionViewModel.swift** - Updated to limit collections for non-premium users:
   - Free users can create only 1 collection
   - Premium users can create unlimited collections

6. **Card_Valuw_ScannerApp.swift** - Updated to initialize subscription service:
   - Provides app-wide access to subscription status
   - Updates subscription status when app launches or becomes active

7. **Products.storekit** - Configuration file for testing in-app purchases:
   - Yearly subscription: ₹2,499.00/year
   - Weekly subscription with 3-day free trial: ₹799.00/week

8. **Card Valuw Scanner.entitlements** - Enables StoreKit testing

## Premium Features Gated

The following features are now gated behind the premium subscription:

1. **In-depth market analysis** - Price history charts in CardDetailView
2. **Live eBay prices & sale trends** - Marketplace deals in CardDetailView
3. **Valuations by grade & edition** - Premium feature in CardDetailView
4. **Add unlimited collections** - Limited to 1 collection for free users

## Implementation Details

### StoreKit 2 Integration

- Uses the modern async/await API for StoreKit 2
- Handles transaction verification
- Provides real-time subscription status updates
- Supports restore purchases functionality

### Premium Feature Access Control

- Uses the `canAccessPremiumFeature()` method to check if a user can access a specific feature
- Each premium feature is defined in the `PremiumFeature` enum
- Some features may be partially available in the free tier (e.g., creating 1 collection)

### UI for Premium Features

- Premium-locked features show a "locked" UI with an upgrade button
- Users can easily see which features require a premium subscription
- The upgrade button takes users directly to the subscription screen

### Testing

- The app includes a StoreKit configuration file for testing
- Developers can test purchases without making actual payments
- The README includes instructions for setting up StoreKit testing in Xcode 