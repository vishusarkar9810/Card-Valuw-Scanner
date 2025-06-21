# Pokemon Card Value Scanner

A SwiftUI app for scanning Pokemon cards and getting their market values and collection management.

## Features

- Scan Pokemon cards using the camera
- View card details and market prices
- Track your collection and its value
- Premium features:
  - In-depth market analysis
  - Live eBay prices & sale trends
  - Valuations by grade & edition
  - Add unlimited collections

## Testing StoreKit Subscriptions

This app uses StoreKit 2 for in-app subscriptions. To test the subscription feature:

1. Run the app in the Xcode simulator or on a device
2. Navigate to the Settings tab
3. Tap "Upgrade to Premium"
4. Choose a subscription plan (Yearly Plan or 3-Day Trial)
5. Complete the purchase using the StoreKit testing environment

### StoreKit Testing Configuration

The app includes a `Products.storekit` file for testing in-app purchases. This configuration includes:

- Yearly Plan subscription: ₹2,499.00 per year
- Weekly subscription with 3-Day free trial: ₹799.00 per week

To enable StoreKit testing in Xcode:

1. Open the scheme editor (Product > Scheme > Edit Scheme)
2. Select the "Run" action
3. Go to the "Options" tab
4. Set "StoreKit Configuration" to "Products.storekit"

## Premium Features

The following features are available only to premium subscribers:

- **In-depth market analysis**: View price history charts and trends
- **Live eBay prices & sale trends**: See real-time marketplace deals
- **Valuations by grade & edition**: Get detailed pricing by card condition
- **Add unlimited collections**: Free users are limited to 1 collection

## Development

This app is built using:

- SwiftUI for the UI
- SwiftData for local data persistence
- StoreKit 2 for in-app subscriptions
- Pokemon TCG API for card data

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+ 