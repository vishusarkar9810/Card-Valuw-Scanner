import Foundation
import SwiftUI

enum SortOption {
    case name
    case number
    case rarity
}

@Observable
final class BrowseViewModel {
    // MARK: - Properties
    
    // Services
    let pokemonTCGService: PokemonTCGService
    var persistenceManager: PersistenceManager
    
    // State
    var sets: [Set] = []
    var filteredSets: [Set] = []
    var cards: [Card] = []
    var filteredCards: [Card] = []
    var isLoading = false
    var errorMessage: String? = nil
    
    // MARK: - Initialization
    
    init(pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
    }
    
    /// Convenience initializer with just persistence manager
    /// - Parameter persistenceManager: The persistence manager to use
    convenience init(persistenceManager: PersistenceManager) {
        self.init(
            pokemonTCGService: PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey),
            persistenceManager: persistenceManager
        )
    }
    
    // MARK: - Methods
    
    /// Update the persistence manager
    /// - Parameter persistenceManager: The new persistence manager instance
    func updatePersistenceManager(_ persistenceManager: PersistenceManager) {
        self.persistenceManager = persistenceManager
    }
    
    /// Load all Pokemon card sets
    func loadSets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await pokemonTCGService.getSets()
            
            // Sort sets by release date (newest first)
            let sortedSets = response.data.sorted { 
                ($0.releaseDate ?? "") > ($1.releaseDate ?? "") 
            }
            
            sets = sortedSets
            filteredSets = sortedSets
            isLoading = false
        } catch {
            errorMessage = "Error loading sets: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Load cards in a specific set
    /// - Parameter set: The set to load cards from
    func loadCardsInSet(set: Set) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let query = ["q": "set.id:\(set.id)", "page": "1", "pageSize": "250"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            cards = response.data
            filteredCards = response.data
            isLoading = false
        } catch {
            errorMessage = "Error loading cards: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Search sets by name
    /// - Parameter searchText: The search text
    func searchSets(searchText: String) {
        if searchText.isEmpty {
            filteredSets = sets
        } else {
            filteredSets = sets.filter { set in
                set.name.lowercased().contains(searchText.lowercased()) ||
                set.series.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    /// Search cards in the current set
    /// - Parameter searchText: The search text
    func searchCardsInSet(searchText: String) {
        if searchText.isEmpty {
            filteredCards = cards
        } else {
            filteredCards = cards.filter { card in
                card.name.lowercased().contains(searchText.lowercased()) ||
                (card.types?.joined(separator: " ").lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
    }
    
    /// Sort cards by the specified option
    /// - Parameter option: The sort option
    func sortCardsBy(_ option: SortOption) {
        switch option {
        case .name:
            filteredCards.sort { $0.name < $1.name }
        case .number:
            // Sort by card number if available
            filteredCards.sort { card1, card2 in
                let id1 = card1.id.components(separatedBy: "-").last ?? ""
                let id2 = card2.id.components(separatedBy: "-").last ?? ""
                return id1 < id2
            }
        case .rarity:
            // Sort by rarity (this is a simplified approach)
            filteredCards.sort { card1, card2 in
                let rarity1 = card1.subtypes?.contains("Rare") ?? false
                let rarity2 = card2.subtypes?.contains("Rare") ?? false
                
                if rarity1 && !rarity2 {
                    return true
                } else if !rarity1 && rarity2 {
                    return false
                } else {
                    return card1.name < card2.name
                }
            }
        }
    }
    
    /// Add a card to the user's collection
    /// - Parameter card: The card to add
    func addCardToCollection(_ card: Card) {
        // Get all collections
        let collections = persistenceManager.fetchAllCollections()
        
        // Find the "My Collection" collection (non-default)
        if let myCollection = collections.first(where: { $0.name == "My Collection" && !$0.isDefault }) {
            // Add the card to the "My Collection" collection
            let cardEntity = persistenceManager.addCard(card, to: myCollection)
            
            // Ensure the card has a price
            if cardEntity.currentPrice == nil {
                // Try to set a price from cardmarket if tcgplayer prices are not available
                if let marketPrice = card.cardmarket?.prices?.averageSellPrice ?? card.cardmarket?.prices?.trendPrice {
                    cardEntity.currentPrice = marketPrice
                    persistenceManager.updateCard(cardEntity)
                }
            }
        } else if let nonDefaultCollection = collections.first(where: { !$0.isDefault }) {
            // Fallback to any non-default collection if "My Collection" doesn't exist
            let cardEntity = persistenceManager.addCard(card, to: nonDefaultCollection)
            
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