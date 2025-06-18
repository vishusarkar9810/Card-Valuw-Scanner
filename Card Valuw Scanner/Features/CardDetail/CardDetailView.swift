import SwiftUI

struct CardDetailView: View {
    let card: Card
    @State private var viewModel: CardDetailViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    
    init(card: Card, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.card = card
        self._viewModel = State(initialValue: CardDetailViewModel(
            card: card,
            pokemonTCGService: pokemonTCGService,
            persistenceManager: persistenceManager
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Card image
                if let imageURL = URL(string: card.images.large) {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        } else if phase.error != nil {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                )
                                .cornerRadius(12)
                        } else {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .overlay(
                                    ProgressView()
                                )
                                .cornerRadius(12)
                        }
                    }
                }
                
                // Card details
                Group {
                    Text(card.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(card.supertype)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        
                        if let types = card.types, !types.isEmpty {
                            ForEach(types, id: \.self) { type in
                                Text(type)
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                        
                        if let hp = card.hp {
                            Spacer()
                            Text("HP: \(hp)")
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                    
                    if let evolvesFrom = card.evolvesFrom {
                        Text("Evolves from: \(evolvesFrom)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let rules = card.rules, !rules.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rules")
                                .font(.headline)
                            
                            ForEach(rules, id: \.self) { rule in
                                Text(rule)
                                    .font(.body)
                                    .padding(10)
                                    .background(Color.yellow.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Divider()
                
                // Price history chart
                if !viewModel.priceHistory.isEmpty {
                    PriceHistoryChart(priceHistory: viewModel.priceHistory)
                        .redacted(reason: viewModel.isPriceHistoryLoading ? .placeholder : [])
                        .overlay {
                            if viewModel.isPriceHistoryLoading {
                                ProgressView()
                            }
                        }
                } else if viewModel.isPriceHistoryLoading {
                    VStack {
                        Text("Loading price history...")
                            .font(.caption)
                        ProgressView()
                    }
                    .frame(height: 200)
                } else {
                    Text("No price history available")
                        .foregroundColor(.secondary)
                        .frame(height: 100)
                }
                
                // Market prices
                Group {
                    Text("Market Prices")
                        .font(.headline)
                    
                    if let tcgplayer = card.tcgplayer, let prices = tcgplayer.prices {
                        VStack(spacing: 8) {
                            if let normal = prices.normal {
                                priceSection(title: "Normal", prices: normal)
                            }
                            
                            if let holofoil = prices.holofoil {
                                priceSection(title: "Holofoil", prices: holofoil)
                            }
                            
                            if let reverseHolofoil = prices.reverseHolofoil {
                                priceSection(title: "Reverse Holofoil", prices: reverseHolofoil)
                            }
                        }
                        
                        if let url = URL(string: tcgplayer.url) {
                            Link("View on TCGPlayer", destination: url)
                                .font(.subheadline)
                                .padding(.top, 8)
                        }
                    } else if let cardmarket = card.cardmarket, let prices = cardmarket.prices {
                        VStack(alignment: .leading, spacing: 8) {
                            if let avg = prices.averageSellPrice {
                                priceRow(label: "Average", value: avg)
                            }
                            
                            if let low = prices.lowPrice {
                                priceRow(label: "Low", value: low)
                            }
                            
                            if let trend = prices.trendPrice {
                                priceRow(label: "Trend", value: trend)
                            }
                        }
                        .padding(.leading, 8)
                        
                        if let url = URL(string: cardmarket.url) {
                            Link("View on Cardmarket", destination: url)
                                .font(.subheadline)
                                .padding(.top, 8)
                        }
                    } else {
                        Text("No price information available")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Related cards section
                RelatedCardsView(cards: viewModel.relatedCards) { selectedCard in
                    // This will be handled by the navigation link
                }
                .redacted(reason: viewModel.isLoading ? .placeholder : [])
                .overlay {
                    if viewModel.isLoading {
                        ProgressView()
                    }
                }
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
        }
        .navigationTitle("Card Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.toggleCollectionStatus()
                }) {
                    Image(systemName: viewModel.isInCollection() ? "heart.fill" : "heart")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    shareCard()
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await viewModel.fetchRelatedCards()
            await viewModel.fetchPriceHistory()
        }
    }
    
    private func shareCard() {
        let activityVC = viewModel.shareCard()
        
        // Find the root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Present the activity view controller
        rootViewController.present(activityVC, animated: true)
    }
    
    private func priceSection(title: String, prices: PriceDetails) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(spacing: 4) {
                if let low = prices.low {
                    priceRow(label: "Low", value: low)
                }
                
                if let mid = prices.mid {
                    priceRow(label: "Mid", value: mid)
                }
                
                if let high = prices.high {
                    priceRow(label: "High", value: high)
                }
                
                if let market = prices.market {
                    priceRow(label: "Market", value: market)
                }
                
                if let directLow = prices.directLow {
                    priceRow(label: "Direct Low", value: directLow)
                }
            }
            .padding(.leading, 8)
        }
        .padding(10)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func priceRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text("$\(String(format: "%.2f", value))")
                .fontWeight(.semibold)
        }
    }
} 