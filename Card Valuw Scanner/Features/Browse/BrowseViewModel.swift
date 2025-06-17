import Foundation
import SwiftUI

enum SortOption {
    case name
    case number
    case rarity
}

class BrowseViewModel: ObservableObject {
    // MARK: - Properties
    
    private let pokemonTCGService: PokemonTCGService
    private var persistenceManager: PersistenceManager
    
    // State
    @Published var sets: [Set] = []
    @Published var filteredSets: [Set] = []
    @Published var cards: [Card] = []
    @Published var filteredCards: [Card] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Initialization
    
    init(pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
    }
    
    // MARK: - Methods
    
    /// Update the persistence manager
    /// - Parameter newPersistenceManager: The new persistence manager
    func updatePersistenceManager(_ newPersistenceManager: PersistenceManager) {
        self.persistenceManager = newPersistenceManager
    }
    
    /// Load all Pokemon card sets
    func loadSets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await pokemonTCGService.getSets()
            
            // Sort sets by release date (newest first)
            let sortedSets = response.data.sorted { 
                $0.releaseDate > $1.releaseDate 
            }
            
            DispatchQueue.main.async {
                self.sets = sortedSets
                self.filteredSets = sortedSets
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error loading sets: \(error.localizedDescription)"
                self.isLoading = false
            }
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
            
            DispatchQueue.main.async {
                self.cards = response.data
                self.filteredCards = response.data
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Error loading cards: \(error.localizedDescription)"
                self.isLoading = false
            }
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
        let _ = persistenceManager.addCard(card)
    }
} 