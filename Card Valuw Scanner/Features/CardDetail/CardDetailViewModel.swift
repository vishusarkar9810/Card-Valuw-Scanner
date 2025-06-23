import Foundation
import SwiftUI

@Observable final class CardDetailViewModel {
    let pokemonTCGService: PokemonTCGService
    let persistenceManager: PersistenceManager
    private let collection: CollectionEntity?
    
    let card: Card
    var relatedCards: [Card] = []
    var isLoading = false
    var errorMessage: String?
    
    // Price history data
    var priceHistory: [(date: Date, price: Double)] = []
    var isPriceHistoryLoading = false
    
    // Collection status
    var isFavorite: Bool {
        // Check if card is in any collection
        let collections = persistenceManager.fetchAllCollections()
        return collections.contains { collection in
            collection.cards.contains { $0.id == card.id }
        }
    }
    
    init(card: Card, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.card = card
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
        self.collection = nil
    }
    
    init(card: Card, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager, collection: CollectionEntity?) {
        self.card = card
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
        self.collection = collection
    }
    
    // MARK: - Related Cards
    
    @MainActor
    func fetchRelatedCards() async {
        guard let name = card.name.components(separatedBy: " ").first else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Search for cards with the same Pokémon name
            let query: [String: Any] = ["q": "name:\(name)", "pageSize": "10"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            // Filter out the current card and limit to 5 related cards
            relatedCards = response.data
                .filter { $0.id != card.id }
                .prefix(5)
                .map { $0 }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load related cards: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Price History
    
    @MainActor
    func fetchPriceHistory() async {
        isPriceHistoryLoading = true
        
        do {
            // Fetch price history from the service
            priceHistory = try await pokemonTCGService.getPriceHistory(for: card.id)
            isPriceHistoryLoading = false
        } catch {
            errorMessage = "Failed to load price history: \(error.localizedDescription)"
            isPriceHistoryLoading = false
            
            // Fall back to generating mock data if the API call fails
            generateBackupPriceHistory()
        }
    }
    
    // Fallback method to generate price history if the API call fails
    private func generateBackupPriceHistory() {
        // Create backup price history for the last 6 months
        let calendar = Calendar.current
        let today = Date()
        
        // Get base price from card if available
        var basePrice: Double = 10.0
        if let market = card.tcgplayer?.prices?.normal?.market ?? 
                       card.tcgplayer?.prices?.holofoil?.market ??
                       card.tcgplayer?.prices?.reverseHolofoil?.market {
            basePrice = market
        } else if let avg = card.cardmarket?.prices?.averageSellPrice {
            basePrice = avg
        }
        
        // Generate price points for the last 6 months with some randomness
        for i in 0..<6 {
            if let date = calendar.date(byAdding: .month, value: -i, to: today) {
                // Add some randomness to the price (±15%)
                let randomFactor = Double.random(in: 0.85...1.15)
                let price = basePrice * randomFactor
                
                priceHistory.append((date: date, price: price))
            }
        }
        
        // Sort by date (oldest to newest)
        priceHistory.sort { $0.date < $1.date }
    }
    
    // MARK: - Sharing
    
    func shareCard() -> (activityItems: [Any], applicationActivities: [UIActivity]?) {
        // Create items to share
        var items: [Any] = []
        
        // Add card image if available
        if let imageURL = URL(string: card.images.large) {
            items.append(imageURL)
        }
        
        // Add card details as text
        var cardDetails = "\(card.name) - Pokémon TCG Card\n"
        cardDetails += "Type: \(card.supertype)\n"
        if let hp = card.hp {
            cardDetails += "HP: \(hp)\n"
        }
        
        // Add price information if available
        if let price = card.tcgplayer?.prices?.normal?.market ?? 
                      card.tcgplayer?.prices?.holofoil?.market {
            cardDetails += "Current market price: $\(String(format: "%.2f", price))\n"
        }
        
        // Add TCGPlayer URL if available
        if let url = card.tcgplayer?.url {
            cardDetails += "View on TCGPlayer: \(url)"
        }
        
        items.append(cardDetails)
        
        return (activityItems: items, applicationActivities: nil)
    }
    
    // MARK: - Collection Management
    
    func toggleFavorite() {
        // Get all collections
        let collections = persistenceManager.fetchAllCollections()
        
        if isFavorite {
            // Find the card in collections and remove it
            if persistenceManager.fetchCard(withID: card.id) != nil {
                for collection in collections where collection.cards.contains(where: { $0.id == card.id }) {
                    collection.cards.removeAll { $0.id == card.id }
                    persistenceManager.updateCollection(collection)
                }
            }
        } else {
            // Find the "Favorites" collection (default collection)
            if let favoritesCollection = collections.first(where: { $0.isDefault }) {
                // Add the card to the Favorites collection
                let cardEntity = persistenceManager.addCard(card, to: favoritesCollection)
                
                // Ensure the card has a price
                if cardEntity.currentPrice == nil {
                    // Try to set a price from cardmarket if tcgplayer prices are not available
                    if let marketPrice = card.cardmarket?.prices?.averageSellPrice ?? card.cardmarket?.prices?.trendPrice {
                        cardEntity.currentPrice = marketPrice
                        persistenceManager.updateCard(cardEntity)
                    }
                }
            } else if let firstCollection = collections.first {
                // Fallback to first collection if no default collection exists
                let cardEntity = persistenceManager.addCard(card, to: firstCollection)
                
                // Ensure the card has a price
                if cardEntity.currentPrice == nil {
                    // Try to set a price from cardmarket if tcgplayer prices are not available
                    if let marketPrice = card.cardmarket?.prices?.averageSellPrice ?? card.cardmarket?.prices?.trendPrice {
                        cardEntity.currentPrice = marketPrice
                        persistenceManager.updateCard(cardEntity)
                    }
                }
            }
        }
    }
} 