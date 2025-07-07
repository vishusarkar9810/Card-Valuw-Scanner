import SwiftUI

struct BasicPriceChart: View {
    let priceHistory: [(date: Date, price: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(.primary)
                Text("Price History")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)
            
            // Basic chart
            chartView
                .frame(height: 220)
            
            // Stats row
            HStack(spacing: 16) {
                statView(title: "Min", value: minPrice, color: .blue)
                statView(title: "Avg", value: avgPrice, color: .purple)
                statView(title: "Max", value: maxPrice, color: .red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var chartView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height - 30 // Adjust for labels
            let maxY = priceHistory.map { $0.price }.max() ?? 1
            let minY = priceHistory.map { $0.price }.min() ?? 0
            let yRange = max(0.01, maxY - minY)
            
            ZStack {
                // Grid lines
                VStack(spacing: height / 4) {
                    ForEach(0..<5) { _ in
                        Divider()
                            .background(Color.gray.opacity(0.3))
                    }
                }
                
                // Area fill
                Path { path in
                    // Start at bottom left
                    path.move(to: CGPoint(x: 0, y: height))
                    
                    // First point
                    if let first = priceHistory.first {
                        let firstY = height - (height * CGFloat((first.price - minY) / yRange))
                        path.addLine(to: CGPoint(x: 0, y: firstY))
                    }
                    
                    // All points
                    for (index, point) in priceHistory.enumerated() {
                        let x = width * (CGFloat(index) / CGFloat(max(1, priceHistory.count - 1)))
                        let y = height - (height * CGFloat((point.price - minY) / yRange))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    // Close path
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(Color.blue.opacity(0.1))
                
                // Line
                Path { path in
                    if let first = priceHistory.first {
                        let firstY = height - (height * CGFloat((first.price - minY) / yRange))
                        path.move(to: CGPoint(x: 0, y: firstY))
                    }
                    
                    for (index, point) in priceHistory.enumerated() {
                        let x = width * (CGFloat(index) / CGFloat(max(1, priceHistory.count - 1)))
                        let y = height - (height * CGFloat((point.price - minY) / yRange))
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                
                // Points
                ForEach(priceHistory.indices, id: \.self) { index in
                    let point = priceHistory[index]
                    let x = width * (CGFloat(index) / CGFloat(max(1, priceHistory.count - 1)))
                    let y = height - (height * CGFloat((point.price - minY) / yRange))
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
                
                // X-axis labels
                HStack {
                    ForEach(getDateIndices(), id: \.self) { index in
                        Text(formatDate(priceHistory[index].date))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .offset(y: height + 15)
            }
        }
    }
    
    private func statView(title: String, value: Double, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(value, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
    
    private var minPrice: Double {
        priceHistory.map { $0.price }.min() ?? 0
    }
    
    private var maxPrice: Double {
        priceHistory.map { $0.price }.max() ?? 0
    }
    
    private var avgPrice: Double {
        let sum = priceHistory.reduce(0) { $0 + $1.price }
        return sum / Double(max(1, priceHistory.count))
    }
    
    private func getDateIndices() -> [Int] {
        let count = priceHistory.count
        if count <= 3 {
            return Array(0..<count)
        } else if count <= 6 {
            return [0, count / 2, count - 1]
        } else {
            return [0, count / 4, count / 2, 3 * count / 4, count - 1]
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
