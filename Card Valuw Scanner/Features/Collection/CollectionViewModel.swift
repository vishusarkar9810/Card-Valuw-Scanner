import Foundation
import SwiftUI
import Observation
import OSLog

@Observable
final class CollectionViewModel {
    private let logger = Logger(subsystem: "com.app.cardvaluescanner", category: "CollectionViewModel")
    private let pokemonTCGService: PokemonTCGService
    var persistenceManager: PersistenceManager
    
    // MARK: - Published properties
    
    var cards: [Card] = []
    var cardEntities: [CardEntity] = []
    var collections: [CollectionEntity] = []
    var selectedCollection: CollectionEntity?
    var isLoading = false
    var errorMessage: String?
    var showingCreateCollection = false
    var newCollectionName = ""
    var shouldRefresh = false
    
    // MARK: - Filter properties
    var searchText = ""
    var selectedTypeFilter: String?
    var selectedRarityFilter: String?
    var selectedSetFilter: String?
    var selectedSortOrder: SortOrder = .dateAdded
    var selectedTypes: [String] = []
    var selectedSets: [String] = []
    var showFavoritesOnly = false
    
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
    
    init(pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
        loadCollections()
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
    
    /// Create a new collection
    func createCollection() {
        guard !newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let collection = persistenceManager.createCollection(name: newCollectionName)
        collections.append(collection)
        newCollectionName = ""
        showingCreateCollection = false
    }
    
    /// Delete a collection
    func deleteCollection(_ collection: CollectionEntity) {
        persistenceManager.deleteCollection(collection)
        collections.removeAll { $0.id == collection.id }
        
        // If the deleted collection was the selected one, select another one
        if selectedCollection?.id == collection.id {
            selectedCollection = collections.first(where: { $0.isDefault }) ?? collections.first
            loadCollection()
        }
    }
    
    /// Select a collection
    func selectCollection(_ collection: CollectionEntity) {
        selectedCollection = collection
        loadCollection()
    }
    
    /// Load the user's collection from persistent storage
    func loadCollection() {
        isLoading = true
        errorMessage = nil
        shouldRefresh = false
        
        guard let collection = selectedCollection else {
            cards = []
            cardEntities = []
            isLoading = false
            return
        }
        
        // Get cards from the selected collection
        cardEntities = Array(collection.cards)
        
        // Convert CardEntity objects to Card objects for display
        cards = cardEntities.map { $0.toCard() }
        
        // Apply any active filters
        applyFilters()
        
        isLoading = false
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
        
        // Apply type filter if selected
        if let typeFilter = selectedTypeFilter {
            filtered = filtered.filter { card in
                card.types?.contains(typeFilter) ?? false
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
        
        // Apply set filter if selected
        if let setFilter = selectedSetFilter {
            filtered = filtered.filter { card in
                card.set?.id == setFilter
            }
        }
        
        // Apply sets filter from selectedSets array
        if !selectedSets.isEmpty {
            filtered = filtered.filter { card in
                guard let setId = card.set?.id else { return false }
                return selectedSets.contains(setId)
            }
        }
        
        // Apply rarity filter if selected
        if let rarityFilter = selectedRarityFilter {
            filtered = filtered.filter { card in
                // Check subtypes first
                if let subtypes = card.subtypes, !subtypes.isEmpty {
                    return subtypes.contains { subtype in
                        subtype.lowercased().contains(rarityFilter.lowercased())
                    }
                }
                // Fall back to rarity property if available
                if let rarity = card.rarity {
                    return rarity.lowercased().contains(rarityFilter.lowercased())
                }
                return false
            }
        }
        
        // Apply favorites filter
        if showFavoritesOnly {
            let favoriteIds = cardEntities.filter { $0.isFavorite }.map { $0.id }
            filtered = filtered.filter { favoriteIds.contains($0.id) }
        }
        
        // Apply sort order
        switch selectedSortOrder {
        case .dateAdded:
            // Just use the current filtered order
            cards = filtered
        case .nameAsc:
            cards = filtered.sorted { $0.name < $1.name }
        case .nameDesc:
            cards = filtered.sorted { $0.name > $1.name }
        case .valueAsc:
            cards = filtered.sorted {
                let value1 = $0.tcgplayer?.prices?.normal?.market ?? 
                             $0.tcgplayer?.prices?.holofoil?.market ?? 
                             $0.tcgplayer?.prices?.reverseHolofoil?.market ?? 0
                
                let value2 = $1.tcgplayer?.prices?.normal?.market ?? 
                             $1.tcgplayer?.prices?.holofoil?.market ?? 
                             $1.tcgplayer?.prices?.reverseHolofoil?.market ?? 0
                
                return value1 < value2
            }
        case .valueDesc:
            cards = filtered.sorted {
                let value1 = $0.tcgplayer?.prices?.normal?.market ?? 
                             $0.tcgplayer?.prices?.holofoil?.market ?? 
                             $0.tcgplayer?.prices?.reverseHolofoil?.market ?? 0
                
                let value2 = $1.tcgplayer?.prices?.normal?.market ?? 
                             $1.tcgplayer?.prices?.holofoil?.market ?? 
                             $1.tcgplayer?.prices?.reverseHolofoil?.market ?? 0
                
                return value1 > value2
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
        selectedSortOrder = .dateAdded
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
        selectedSortOrder = order
        applyFilters()
    }
    
    // MARK: - Card Operations
    
    /// Remove a card from the collection
    func removeCard(with id: String) {
        if let _ = persistenceManager.fetchCard(withID: id), let collection = selectedCollection {
            collection.cards.removeAll { $0.id == id }
            persistenceManager.updateCollection(collection)
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
    
    /// Move a card to another collection
    func moveCard(_ card: CardEntity, to destinationCollection: CollectionEntity) {
        guard let sourceCollection = selectedCollection else { return }
        
        persistenceManager.moveCard(card, from: sourceCollection, to: destinationCollection)
        loadCollection()
    }
} 