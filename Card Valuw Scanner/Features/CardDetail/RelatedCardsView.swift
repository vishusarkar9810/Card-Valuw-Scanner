import SwiftUI

struct RelatedCardsView: View {
    let cards: [Card]
    let onCardSelected: (Card) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Cards")
                .font(.headline)
                .padding(.bottom, 4)
            
            if cards.isEmpty {
                Text("No related cards found")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cards) { card in
                            RelatedCardItem(card: card)
                                .onTapGesture {
                                    onCardSelected(card)
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct RelatedCardItem: View {
    let card: Card
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            if let imageUrl = URL(string: card.images.small) {
                AsyncImage(url: imageUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .frame(height: 120)
                    } else if phase.error != nil {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                            .frame(width: 80, height: 120)
                    } else {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.2))
                            .aspectRatio(2/3, contentMode: .fit)
                            .frame(height: 120)
                            .overlay(ProgressView())
                    }
                }
            }
            
            Text(card.name)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 80)
                .multilineTextAlignment(.center)
                
            if let price = card.tcgplayer?.prices?.normal?.market ?? 
                          card.tcgplayer?.prices?.holofoil?.market {
                Text("$\(String(format: "%.2f", price))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 90)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.5))
        .cornerRadius(10)
        .shadow(radius: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
} 