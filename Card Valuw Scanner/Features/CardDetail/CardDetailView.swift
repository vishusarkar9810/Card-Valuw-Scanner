import SwiftUI

struct CardDetailView: View {
    let card: Card
    @State private var viewModel: CardDetailViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRelatedCard: Card?
    
    init(card: Card, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.card = card
        self._viewModel = State(initialValue: CardDetailViewModel(
            card: card,
            pokemonTCGService: pokemonTCGService,
            persistenceManager: persistenceManager
        ))
    }
    
    init(card: Card, collection: CollectionEntity?, persistenceManager: PersistenceManager) {
        self.card = card
        self._viewModel = State(initialValue: CardDetailViewModel(
            card: card,
            pokemonTCGService: PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey),
            persistenceManager: persistenceManager,
            collection: collection
        ))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Card image
                AsyncImage(url: URL(string: card.images.large)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(height: 300)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .frame(height: 300)
                    @unknown default:
                        EmptyView()
                    }
                }
                .cornerRadius(12)
                
                // Card info
                VStack(alignment: .leading, spacing: 8) {
                    Text(card.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let set = card.set {
                        Text(set.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let number = card.number {
                        Text("Card #: \(number)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else {
                    Text("No price history available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                
                Divider()
                
                // Marketplace deals section
                MarketplaceDealsView(card: card)
                
                Divider()
                
                // Related cards
                if !viewModel.relatedCards.isEmpty {
                    RelatedCardsView(cards: viewModel.relatedCards) { selectedCard in
                        self.selectedRelatedCard = selectedCard
                    }
                } else if viewModel.isLoading {
                    VStack {
                        Text("Loading related cards...")
                            .font(.caption)
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                } else {
                    Text("No related cards found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                
                Divider()
                
                // Card details
                Group {
                    detailRow(label: "Type", value: card.supertype)
                    
                    if let hp = card.hp {
                        detailRow(label: "HP", value: hp)
                    }
                    
                    if let types = card.types, !types.isEmpty {
                        detailRow(label: "Types", value: types.joined(separator: ", "))
                    }
                    
                    if let rules = card.rules, !rules.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rules")
                                .font(.headline)
                            ForEach(rules, id: \.self) { rule in
                                Text(rule)
                                    .font(.body)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Image(systemName: viewModel.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isFavorite ? .red : nil)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareCard()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task {
            await viewModel.fetchRelatedCards()
            await viewModel.fetchPriceHistory()
        }
        .sheet(item: $selectedRelatedCard) { relatedCard in
            NavigationStack {
                CardDetailView(
                    card: relatedCard,
                    pokemonTCGService: viewModel.pokemonTCGService,
                    persistenceManager: viewModel.persistenceManager
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            selectedRelatedCard = nil
                        }
                    }
                }
            }
        }
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.headline)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 2)
    }
    
    private func priceRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            Text("$\(String(format: "%.2f", value))")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 1)
    }
    
    private func priceSection(title: String, prices: PriceDetails) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            
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
        }
    }
    
    private func shareCard() {
        // Create items to share
        var items: [Any] = []
        
        // Add card name and set
        var shareText = "Check out this Pokémon card: \(card.name)"
        if let set = card.set {
            shareText += " from \(set.name)"
        }
        items.append(shareText)
        
        // Add card image if available
        if let url = URL(string: card.images.large) {
            items.append(url)
        }
        
        // Present share sheet
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
} 