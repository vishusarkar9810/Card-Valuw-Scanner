import Foundation
import SwiftUI

@Observable final class CardDetailViewModel {
    private let pokemonTCGService: PokemonTCGService
    private let persistenceManager: PersistenceManager
    
    let card: Card
    var relatedCards: [Card] = []
    var isLoading = false
    var errorMessage: String?
    
    // Mock price history data - in a real app, this would come from an API or local storage
    var priceHistory: [(date: Date, price: Double)] = []
    
    init(card: Card, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.card = card
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
        
        // Generate mock price history data
        generateMockPriceHistory()
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
    
    private func generateMockPriceHistory() {
        // Create mock price history for the last 6 months
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
    
    func shareCard() -> UIActivityViewController {
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
        
        // Create and configure activity view controller
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        return activityViewController
    }
    
    // MARK: - Collection Management
    
    func isInCollection() -> Bool {
        return persistenceManager.isCardInCollection(cardId: card.id)
    }
    
    func toggleCollectionStatus() {
        if isInCollection() {
            persistenceManager.removeCardFromCollection(cardId: card.id)
        } else {
            persistenceManager.addCardToCollection(card: card)
        }
    }
} 