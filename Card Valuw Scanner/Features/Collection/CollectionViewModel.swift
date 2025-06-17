import Foundation
import SwiftUI
import Observation

@Observable
final class CollectionViewModel {
    // MARK: - Properties
    
    private let pokemonTCGService: PokemonTCGService
    private var persistenceManager: PersistenceManager
    
    // State
    var cards: [Card] = []
    var cardEntities: [CardEntity] = []
    var isLoading = false
    var errorMessage: String? = nil
    
    // Filters
    var searchText = ""
    var selectedTypes: [String] = []
    var selectedSets: [String] = []
    var showFavoritesOnly = false
    
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
        // Reload collection with the new persistence manager
        loadCollection()
    }
    
    /// Load the user's collection from persistent storage
    func loadCollection() {
        isLoading = true
        errorMessage = nil
        
        // Fetch all cards from the persistence manager
        cardEntities = persistenceManager.fetchAllCards()
        
        // Convert CardEntity objects to Card objects for display
        cards = cardEntities.map { $0.toCard() }
        
        // Apply any active filters
        applyFilters()
        
        isLoading = false
    }
    
    /// Apply current filters to the collection
    func applyFilters() {
        var filteredEntities = cardEntities
        
        // Filter by search text
        if !searchText.isEmpty {
            filteredEntities = filteredEntities.filter { entity in
                entity.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        // Filter by types
        if !selectedTypes.isEmpty {
            filteredEntities = filteredEntities.filter { entity in
                selectedTypes.contains { type in
                    entity.types.contains(type)
                }
            }
        }
        
        // Filter by sets
        if !selectedSets.isEmpty && selectedSets.contains(where: { !$0.isEmpty }) {
            filteredEntities = filteredEntities.filter { entity in
                if let setID = entity.setID {
                    return selectedSets.contains(setID)
                }
                return false
            }
        }
        
        // Filter by favorites
        if showFavoritesOnly {
            filteredEntities = filteredEntities.filter { $0.isFavorite }
        }
        
        // Update cards array with filtered results
        cards = filteredEntities.map { $0.toCard() }
    }
    
    /// Load sample cards for demo purposes
    func loadSampleCards() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sample search for popular Pokemon
            let query = ["q": "name:pikachu OR name:charizard OR name:mewtwo", "page": "1", "pageSize": "20"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            // Add sample cards to collection
            for card in response.data {
                let _ = persistenceManager.addCard(card)
            }
            
            // Reload collection from persistence
            loadCollection()
        } catch {
            errorMessage = "Error loading cards: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Search cards with the current filters
    func searchCards() async {
        isLoading = true
        errorMessage = nil
        
        do {
            var queryParts: [String] = []
            
            // Add search text
            if !searchText.isEmpty {
                queryParts.append("name:\"\(searchText)\"")
            }
            
            // Add type filters
            if !selectedTypes.isEmpty {
                let typeQuery = selectedTypes.map { "types:\($0)" }.joined(separator: " OR ")
                queryParts.append("(\(typeQuery))")
            }
            
            // Add set filters
            if !selectedSets.isEmpty {
                let setQuery = selectedSets.map { "set.id:\($0)" }.joined(separator: " OR ")
                queryParts.append("(\(setQuery))")
            }
            
            // Build the query
            let queryString = queryParts.isEmpty ? "*" : queryParts.joined(separator: " AND ")
            let query = ["q": queryString, "page": "1", "pageSize": "20"]
            
            let response = try await pokemonTCGService.searchCards(query: query)
            cards = response.data
        } catch {
            errorMessage = "Error searching cards: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Get the total value of the collection
    var totalCollectionValue: Double {
        var total = 0.0
        
        for entity in cardEntities {
            if let price = entity.currentPrice {
                total += price * Double(entity.quantity)
            }
        }
        
        return total
    }
    
    /// Reset all filters
    func resetFilters() {
        searchText = ""
        selectedTypes = []
        selectedSets = []
        showFavoritesOnly = false
        loadCollection()
    }
    
    /// Toggle favorite status for a card
    func toggleFavorite(for card: Card) {
        if let entity = persistenceManager.fetchCard(withID: card.id) {
            persistenceManager.toggleFavorite(entity)
            loadCollection()
        }
    }
    
    /// Remove a card from the collection
    func removeCard(with id: String) {
        if let entity = persistenceManager.fetchCard(withID: id) {
            persistenceManager.removeCard(entity)
            loadCollection()
        }
    }
    
    /// Decrease the quantity of a card in the collection
    func decreaseCardQuantity(with id: String) {
        if let entity = persistenceManager.fetchCard(withID: id) {
            let wasRemoved = persistenceManager.decreaseCardQuantity(entity)
            if wasRemoved || entity.quantity <= 1 {
                loadCollection()
            }
        }
    }
    
    /// Increase the quantity of a card in the collection
    func increaseCardQuantity(with id: String) {
        if let entity = persistenceManager.fetchCard(withID: id) {
            entity.quantity += 1
            persistenceManager.updateCard(entity)
        }
    }
} 