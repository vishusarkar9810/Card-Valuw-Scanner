import SwiftUI

struct MarketplaceDealsView: View {
    let card: Card
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart")
                    .font(.title3)
                Text("Deals on marketplaces")
                    .font(.headline)
                Spacer()
            }
            .padding(.bottom, 4)
            
            HStack(spacing: 16) {
                if let tcgplayer = card.tcgplayer {
                    marketplaceCard(
                        title: "TCGPlayer",
                        price: lowestTCGPlayerPrice(tcgplayer),
                        url: URL(string: tcgplayer.url),
                        imageName: "tcgplayer_logo"
                    )
                }
                
                if let cardmarket = card.cardmarket {
                    marketplaceCard(
                        title: "Cardmarket",
                        price: cardmarket.prices?.lowPrice ?? 0,
                        url: URL(string: cardmarket.url),
                        imageName: "cardmarket_logo"
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                .background(Color.white)
        )
        .cornerRadius(12)
    }
    
    private func marketplaceCard(title: String, price: Double, url: URL?, imageName: String) -> some View {
        Button(action: {
            if let url = url {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }) {
            VStack(alignment: .leading) {
                if let image = UIImage(named: imageName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 40)
                        .padding(.vertical, 8)
                } else {
                    // Fallback to SF Symbols if image is not found
                    Image(systemName: title == "TCGPlayer" ? "creditcard" : "cart")
                        .font(.system(size: 32))
                        .foregroundColor(title == "TCGPlayer" ? .blue : .red)
                        .frame(height: 40)
                        .padding(.vertical, 8)
                }
                
                Text(title)
                    .font(.headline)
                
                // Show "N/A" if price is 0
                Text(price > 0 ? "from $\(String(format: "%.2f", price))" : "Price not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(1.0) // Start with normal scale
            // Add direct modifiers instead of using a custom ButtonStyle
            .contentShape(Rectangle())
        }
        // Apply button styling directly
        .buttonStyle(PlainButtonStyle())
    }
    
    private func lowestTCGPlayerPrice(_ tcgplayer: TcgPlayer) -> Double {
        var lowestPrice: Double = Double.greatestFiniteMagnitude
        
        if let prices = tcgplayer.prices {
            if let normal = prices.normal?.low, normal > 0, normal < lowestPrice {
                lowestPrice = normal
            }
            
            if let holofoil = prices.holofoil?.low, holofoil > 0, holofoil < lowestPrice {
                lowestPrice = holofoil
            }
            
            if let reverseHolofoil = prices.reverseHolofoil?.low, reverseHolofoil > 0, reverseHolofoil < lowestPrice {
                lowestPrice = reverseHolofoil
            }
            
            // Try market prices if low prices aren't available
            if lowestPrice == Double.greatestFiniteMagnitude {
                if let normal = prices.normal?.market, normal > 0 {
                    lowestPrice = normal
                } else if let holofoil = prices.holofoil?.market, holofoil > 0 {
                    lowestPrice = holofoil
                } else if let reverseHolofoil = prices.reverseHolofoil?.market, reverseHolofoil > 0 {
                    lowestPrice = reverseHolofoil
                }
            }
        }
        
        return lowestPrice == Double.greatestFiniteMagnitude ? 0 : lowestPrice
    }
} 