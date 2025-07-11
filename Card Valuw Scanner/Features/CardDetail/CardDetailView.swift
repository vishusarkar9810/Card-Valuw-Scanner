import SwiftUI

struct CardDetailView: View {
    // MARK: - Properties
    
    @State private var model: CardDetailViewModel
    @State private var selectedRelatedCard: Card? = nil
    @State private var showingShareSheet = false
    @State private var showSubscriptions = false
    @Environment(\.subscriptionService) private var subscriptionService
    
    // MARK: - Initialization
    
    init(model: CardDetailViewModel) {
        self._model = State(initialValue: model)
    }
    
    // MARK: - Computed Properties
    
    private var card: Card {
        model.card
    }
    
    // MARK: - Body
    
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
                
                // Price history chart (Premium feature)
                if subscriptionService.canAccessPremiumFeature(.marketAnalysis) {
                    if !model.priceHistory.isEmpty {
                        PriceHistoryChart(priceHistory: model.priceHistory)
                            .redacted(reason: model.isPriceHistoryLoading ? .placeholder : [])
                            .overlay {
                                if model.isPriceHistoryLoading {
                                    ProgressView()
                                }
                            }
                    } else if model.isPriceHistoryLoading {
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
                } else {
                    // Premium feature locked UI
                    premiumFeatureLockedView(feature: .marketAnalysis)
                }
                
                Divider()
                
                // Marketplace deals section (Premium feature)
                if subscriptionService.canAccessPremiumFeature(.livePrices) {
                    MarketplaceDealsView(card: card)
                } else {
                    // Premium feature locked UI
                    premiumFeatureLockedView(feature: .livePrices)
                }
                
                Divider()
                
                // Shop on eBay button
                shopOnEbaySection()
                
                Divider()
                
                // Related cards
                if !model.relatedCards.isEmpty {
                    RelatedCardsView(cards: model.relatedCards) { selectedCard in
                        self.selectedRelatedCard = selectedCard
                    }
                } else if model.isLoading {
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
            }
            .padding()
        }
        .navigationTitle("Card Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    model.toggleFavorite()
                }) {
                    Image(systemName: model.isFavorite ? "heart.fill" : "heart")
                        .foregroundColor(model.isFavorite ? .red : .primary)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            let shareData = model.shareCard()
            ActivityViewControllerWrapper(activityItems: shareData.activityItems, applicationActivities: shareData.applicationActivities)
        }
        .sheet(item: $selectedRelatedCard) { card in
            NavigationStack {
                CardDetailView(model: CardDetailViewModel(card: card, pokemonTCGService: model.pokemonTCGService, persistenceManager: model.persistenceManager, collection: nil))
            }
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionView(viewModel: SubscriptionViewModel(subscriptionService: subscriptionService), isPresented: $showSubscriptions)
        }
        .task {
            await model.fetchRelatedCards()
            await model.fetchPriceHistory()
            
            // Update subscription status
            await subscriptionService.updateSubscriptionStatus()
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func shopOnEbaySection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cart.fill")
                    .font(.title3)
                    .foregroundColor(.primary)
                Text("Shop on eBay")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.bottom, 4)
            
            Button(action: {
                openEbaySearch()
            }) {
                VStack(alignment: .leading) {
                    // eBay logo or fallback to SF Symbol
                    if let image = UIImage(named: "ebay_logo") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                            .padding(.vertical, 8)
                    } else {
                        // Fallback to SF Symbols if image is not found
                        HStack {
                            Text("eBay")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 0.85, green: 0, blue: 0))
                            
                            Spacer()
                            
                            Image(systemName: "tag.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(red: 0.85, green: 0, blue: 0))
                        }
                        .frame(height: 40)
                        .padding(.vertical, 8)
                    }
                    
                    Text("Find this card on eBay")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Description text
                    Text("Search for \(card.name) \(card.set?.name ?? "") on eBay")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                .background(Color(.systemBackground))
        )
        .cornerRadius(12)
    }
    
    private func openEbaySearch() {
        // Create search query with card name, set name, and number
        var searchQuery = card.name
        
        if let set = card.set?.name {
            searchQuery += " \(set)"
        }
        
        if let number = card.number {
            searchQuery += " \(number)/\(card.set?.total ?? 0)"
        }
        
        // Add "Pokemon Card" to make the search more specific
        searchQuery += " Pokemon Card"
        
        // Create URL with encoded search query
        if let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://www.ebay.com/sch/i.html?_nkw=\(encodedQuery)") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @ViewBuilder
    private func premiumFeatureLockedView(feature: PremiumFeature) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: feature.iconName)
                    .font(.title3)
                    .foregroundColor(.primary)
                Text(feature.description)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                
                Text("Premium Feature")
                    .font(.headline)
                
                Text("Unlock premium to access \(feature.description.lowercased())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    showSubscriptions = true
                } label: {
                    Text("Upgrade to Premium")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                .background(Color(.systemBackground))
        )
        .cornerRadius(12)
    }
}

// MARK: - Activity View Controller Wrapper

struct ActivityViewControllerWrapper: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
} 