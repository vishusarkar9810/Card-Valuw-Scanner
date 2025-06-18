import SwiftUI

struct PriceHistoryChart: View {
    let priceHistory: [(date: Date, price: Double)]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Price History")
                .font(.headline)
                .padding(.bottom, 4)
            
            // Custom chart implementation
            customPriceChart()
            
            HStack {
                Text("Min: $\(minPrice, specifier: "%.2f")")
                Spacer()
                Text("Avg: $\(avgPrice, specifier: "%.2f")")
                Spacer()
                Text("Max: $\(maxPrice, specifier: "%.2f")")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var minPrice: Double {
        priceHistory.map { $0.price }.min() ?? 0
    }
    
    private var maxPrice: Double {
        priceHistory.map { $0.price }.max() ?? 0
    }
    
    private var avgPrice: Double {
        let sum = priceHistory.reduce(0) { $0 + $1.price }
        return sum / Double(priceHistory.count)
    }
    
    // Display only a subset of dates for better readability
    private var dateLabels: [Int] {
        // For weekly data (26 points), show approximately monthly labels
        let count = priceHistory.count
        if count > 20 {
            // Show approximately 6 labels (roughly monthly for 6 months of data)
            let step = max(1, count / 6)
            return stride(from: 0, to: count, by: step).map { $0 }
        } else {
            // For fewer points, show every other point
            let step = max(1, count / 4)
            return stride(from: 0, to: count, by: step).map { $0 }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // Use abbreviated month name and day
        formatter.dateFormat = "MMM d"
        
        // For better readability in charts
        let dateStr = formatter.string(from: date)
        
        // Make first letter uppercase and rest lowercase
        if let firstChar = dateStr.first {
            return String(firstChar).uppercased() + dateStr.dropFirst().lowercased()
        }
        return dateStr
    }
    
    @ViewBuilder
    private func customPriceChart() -> some View {
        // Simple line chart
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxY = priceHistory.map { $0.price }.max() ?? 1
            let minY = priceHistory.map { $0.price }.min() ?? 0
            let yRange = maxY - minY
            
            // Background grid lines
            VStack(spacing: height / 4) {
                ForEach(0..<5) { _ in
                    Divider()
                        .background(Color.gray.opacity(0.3))
                }
            }
            
            // Price line
            Path { path in
                for (index, point) in priceHistory.enumerated() {
                    let x = width * (CGFloat(index) / CGFloat(max(1, priceHistory.count - 1)))
                    let y = height - (height * CGFloat((point.price - minY) / max(0.01, yRange)))
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.blue, lineWidth: 2)
            
            // Data points
            ForEach(priceHistory.indices, id: \.self) { index in
                let point = priceHistory[index]
                let x = width * (CGFloat(index) / CGFloat(max(1, priceHistory.count - 1)))
                let y = height - (height * CGFloat((point.price - minY) / max(0.01, yRange)))
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .position(x: x, y: y)
            }
            
            // X-axis labels - only show a subset for better readability
            ZStack(alignment: .bottom) {
                // Draw the actual X-axis labels
                ForEach(dateLabels, id: \.self) { index in
                    Text(formatDate(priceHistory[index].date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .position(
                            x: width * (CGFloat(index) / CGFloat(max(1, priceHistory.count - 1))),
                            y: height + 15
                        )
                }
            }
            .frame(width: width, height: 30)
            .offset(y: 15)
        }
        .frame(height: 200)
        .padding(.top, 20)
        .padding(.bottom, 30)
    }
} 