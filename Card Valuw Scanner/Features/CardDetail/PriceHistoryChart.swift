import SwiftUI

struct PriceHistoryChart: View {
    let priceHistory: [(date: Date, price: Double)]
    
    var body: some View {
        BasicPriceChart(priceHistory: priceHistory)
    }
} 