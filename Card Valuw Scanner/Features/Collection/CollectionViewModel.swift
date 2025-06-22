import Foundation
import SwiftUI
import Observation
import OSLog

@Observable
final class CollectionViewModel {
    private let logger = Logger(subsystem: "com.app.cardvaluescanner", category: "CollectionViewModel")
    let pokemonTCGService: PokemonTCGService
    var persistenceManager: PersistenceManager
    private var subscriptionService: SubscriptionService
    
    // MARK: - Published properties
    
    var cards: [Card] = []
    var cardEntities: [CardEntity] = []
    var collections: [CollectionEntity] = []
    var selectedCollection: CollectionEntity?
    var isLoading = false
    var errorMessage: String?
    var showingCreateCollection = false
    var newCollectionName = ""
    var shouldRefresh = true
    var totalCollectionValue: Double = 0.0
    var displayedCollectionValue: Double = 0.0
    
    // MARK: - Search and filter properties
    
    var searchText = ""
    var selectedTypeFilter: String?
    var selectedTypes: [String] = []
    var selectedSetFilter: String?
    var selectedSets: [String] = []
    var selectedRarityFilter: String?
    var showFavoritesOnly = false
    var filteredCards: [Card] = []
    
    // MARK: - Type Definitions
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case dateAdded = "Date Added"
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case valueAsc = "Value (Low to High)"
        case valueDesc = "Value (High to Low)"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Initialization
    
    init(pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager, subscriptionService: SubscriptionService) {
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
        self.subscriptionService = subscriptionService
        self.totalCollectionValue = 0.0
        self.displayedCollectionValue = 0.0
        loadCollections()
        loadCollection()
    }
    
    // MARK: - Methods
    
    // MARK: Collection Management
    
    /// Update the persistence manager reference
    /// - Parameter persistenceManager: The new persistence manager instance
    func updatePersistenceManager(_ persistenceManager: PersistenceManager) {
        self.persistenceManager = persistenceManager
        loadCollections()
        if let selectedCollection = selectedCollection {
            // Try to find the same collection in the new context
            if let newCollection = persistenceManager.fetchAllCollections().first(where: { $0.id == selectedCollection.id }) {
                self.selectedCollection = newCollection
            } else {
                // Fall back to the default collection
                self.selectedCollection = persistenceManager.fetchAllCollections().first(where: { $0.isDefault }) ?? persistenceManager.fetchAllCollections().first
            }
        }
        loadCollection()
    }
    
    /// Update the subscription service reference
    /// - Parameter subscriptionService: The new subscription service instance
    func updateSubscriptionService(_ subscriptionService: SubscriptionService) {
        self.subscriptionService = subscriptionService
    }
    
    /// Create a new collection
    func createCollection() {
        guard !newCollectionName.isEmpty else {
            errorMessage = "Collection name cannot be empty"
            return
        }
        
        // Check if user can create more collections
        if !canCreateMoreCollections() {
            errorMessage = "Upgrade to Premium to create more collections"
            return
        }
        
        do {
            let newCollection = persistenceManager.createCollection(name: newCollectionName)
            collections.append(newCollection)
            newCollectionName = ""
            showingCreateCollection = false
            selectCollection(newCollection)
        } catch {
            errorMessage = "Failed to create collection: \(error.localizedDescription)"
        }
    }
    
    /// Delete a collection
    func deleteCollection(_ collection: CollectionEntity) {
        guard !collection.isDefault else {
            errorMessage = "Cannot delete the default collection"
            return
        }
        
        do {
            persistenceManager.deleteCollection(collection)
            
            // Update collections list
            collections = persistenceManager.fetchAllCollections()
            
            // If the deleted collection was selected, select another one
            if selectedCollection?.id == collection.id {
                if let defaultCollection = collections.first(where: { $0.isDefault }) {
                    selectCollection(defaultCollection)
                } else if let firstCollection = collections.first {
                    selectCollection(firstCollection)
                } else {
                    selectedCollection = nil
                    cardEntities = []
                    filteredCards = []
                }
            }
        } catch {
            errorMessage = "Failed to delete collection: \(error.localizedDescription)"
        }
    }
    
    /// Select a collection
    func selectCollection(_ collection: CollectionEntity) {
        selectedCollection = collection
        cardEntities = Array(collection.cards)
        applyFilters()
    }
    
    /// Load the user's collection from persistent storage
    func loadCollection() {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all collections
            collections = persistenceManager.fetchAllCollections()
            
            // Select the default collection if available
            if let defaultCollection = collections.first(where: { $0.isDefault }) {
                selectCollection(defaultCollection)
            } else if let firstCollection = collections.first {
                selectCollection(firstCollection)
            } else {
                // Create a default collection if none exists
                createDefaultCollection()
            }
            
            isLoading = false
            shouldRefresh = false
        } catch {
            errorMessage = "Failed to load collections: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Calculate the total value of all cards in the collection
    private func calculateTotalCollectionValue() {
        totalCollectionValue = 0.0
        
        for entity in cardEntities {
            let cardPrice = entity.currentPrice ?? 0.0
            totalCollectionValue += (cardPrice * Double(entity.quantity))
        }
        
        // If no filters are applied, set displayed value to total value
        if searchText.isEmpty && selectedTypeFilter == nil && selectedTypes.isEmpty && 
           selectedSetFilter == nil && selectedSets.isEmpty && selectedRarityFilter == nil && 
           !showFavoritesOnly {
            displayedCollectionValue = totalCollectionValue
        } else {
            updateDisplayedCollectionValue()
        }
    }
    
    /// Apply current filters to the collection
    public func applyFilters() {
        var filtered = cards
        
        // Apply text search if any
        if !searchText.isEmpty {
            filtered = filtered.filter { card in
                card.name.lowercased().contains(searchText.lowercased()) ||
                (card.number?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        // Apply types filter from selectedTypes array
        if !selectedTypes.isEmpty {
            filtered = filtered.filter { card in
                guard let cardTypes = card.types else { return false }
                return cardTypes.contains { type in
                    selectedTypes.contains(type)
                }
            }
        }
        
        // Apply type filter if any
        if let type = selectedTypeFilter {
            filtered = filtered.filter { card in
                guard let types = card.types else { return false }
                return types.contains(type)
            }
        }
        
        // Apply set filter if any
        if !selectedSets.isEmpty {
            filtered = filtered.filter { card in
                guard let setID = card.set?.id else { return false }
                return selectedSets.contains(setID)
            }
        }
        
        // Apply set filter if any
        if let set = selectedSetFilter {
            filtered = filtered.filter { card in
                card.set?.id == set
            }
        }
        
        // Apply rarity filter if any
        if let rarity = selectedRarityFilter {
            filtered = filtered.filter { card in
                guard let cardRarity = card.rarity else { return false }
                return cardRarity == rarity
            }
        }
        
        // Apply favorites filter if enabled
        if showFavoritesOnly {
            filtered = filtered.filter { card in
                if let entity = cardEntities.first(where: { $0.id == card.id }) {
                    return entity.isFavorite
                }
                return false
            }
        }
        
        filteredCards = filtered
        updateDisplayedCollectionValue()
    }
    
    /// Update the displayed collection value based on currently filtered cards
    private func updateDisplayedCollectionValue() {
        // If no filters are applied, use the total collection value
        if searchText.isEmpty && selectedTypeFilter == nil && selectedTypes.isEmpty && 
           selectedSetFilter == nil && selectedSets.isEmpty && selectedRarityFilter == nil && 
           !showFavoritesOnly {
            displayedCollectionValue = totalCollectionValue
            return
        }
        
        // Otherwise, calculate value of displayed cards
        displayedCollectionValue = 0.0
        
        // Get filtered card IDs
        let filteredCardIds = filteredCards.map { $0.id }
        
        // Sum up the values of filtered cards
        for entity in cardEntities {
            if filteredCardIds.contains(entity.id) {
                let cardPrice = entity.currentPrice ?? 0.0
                displayedCollectionValue += (cardPrice * Double(entity.quantity))
            }
        }
    }
    
    /// Load all collections from persistent storage
    func loadCollections() {
        collections = persistenceManager.fetchAllCollections()
        
        // If no collection is selected, select the default one or the first one
        if selectedCollection == nil {
            selectedCollection = collections.first { $0.isDefault } ?? collections.first
        }
    }
    
    /// Reset all filters to their default values
    func resetFilters() {
        searchText = ""
        selectedTypeFilter = nil
        selectedRarityFilter = nil
        selectedSetFilter = nil
        selectedTypes = []
        selectedSets = []
        showFavoritesOnly = false
        loadCollection()
    }
    
    /// Set the text search filter
    /// - Parameter text: The search text
    func setSearchText(_ text: String) {
        searchText = text
        applyFilters()
    }
    
    /// Set the type filter
    /// - Parameter type: The type to filter by
    func setTypeFilter(_ type: String?) {
        selectedTypeFilter = type
        applyFilters()
    }
    
    /// Set the rarity filter
    /// - Parameter rarity: The rarity to filter by
    func setRarityFilter(_ rarity: String?) {
        selectedRarityFilter = rarity
        applyFilters()
    }
    
    /// Set the set filter
    /// - Parameter setId: The set ID to filter by
    func setSetFilter(_ setId: String?) {
        selectedSetFilter = setId
        applyFilters()
    }
    
    /// Set the sort order
    /// - Parameter order: The sort order to use
    func setSortOrder(_ order: SortOrder) {
        // Implementation needed
    }
    
    // MARK: - Card Operations
    
    /// Remove a card from the collection
    func removeCard(with id: String) {
        if let _ = persistenceManager.fetchCard(withID: id), let collection = selectedCollection {
            collection.cards.removeAll { $0.id == id }
            persistenceManager.updateCollection(collection)
            loadCollection()
            calculateTotalCollectionValue()
        }
    }
    
    /// Decrease the quantity of a card in the collection
    func decreaseCardQuantity(with id: String) {
        if let entity = persistenceManager.fetchCard(withID: id) {
            let wasRemoved = entity.decreaseQuantity()
            if wasRemoved {
                removeCard(with: id)
            } else {
                persistenceManager.updateCard(entity)
                calculateTotalCollectionValue()
            }
        }
    }
    
    /// Increase the quantity of a card in the collection
    func increaseCardQuantity(with id: String) {
        if let entity = persistenceManager.fetchCard(withID: id) {
            entity.increaseQuantity()
            persistenceManager.updateCard(entity)
            calculateTotalCollectionValue()
        }
    }
    
    /// Toggle favorite status for a card
    func toggleFavorite(for id: String) {
        if let entity = persistenceManager.fetchCard(withID: id) {
            entity.isFavorite.toggle()
            persistenceManager.updateCard(entity)
        }
    }
    
    /// Move a card to another collection
    func moveCard(_ card: CardEntity, to destinationCollection: CollectionEntity) {
        guard let sourceCollection = selectedCollection else { return }
        
        persistenceManager.moveCard(card, from: sourceCollection, to: destinationCollection)
        loadCollection()
        calculateTotalCollectionValue()
    }
    
    // MARK: - Premium Features
    
    func canCreateMoreCollections() -> Bool {
        // If user is premium, they can create unlimited collections
        if subscriptionService.canAccessPremiumFeature(.unlimitedCollections) {
            return true
        }
        
        // Free tier users can only create 1 collection
        return collections.count < 1
    }
    
    private func createDefaultCollection() {
        let defaultCollection = persistenceManager.createCollection(name: "My Collection")
        defaultCollection.isDefault = true
        collections = [defaultCollection]
        selectCollection(defaultCollection)
    }
} 