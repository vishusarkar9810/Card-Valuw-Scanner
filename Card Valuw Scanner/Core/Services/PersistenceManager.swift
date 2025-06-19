import Foundation
import SwiftData
import OSLog

/// A service class that manages persistence operations for the app's data
@Observable
final class PersistenceManager {
    private let logger = Logger(subsystem: "com.app.cardvaluescanner", category: "PersistenceManager")
    private let modelContext: ModelContext
    
    // Default collection
    private var defaultCollection: CollectionEntity?
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.debug("Successfully initialized PersistenceManager with ModelContext")
        
        // Initialize default collection if needed
        initializeDefaultCollection()
    }
    
    /// Initializes the default collection if it doesn't exist
    private func initializeDefaultCollection() {
        let predicate = #Predicate<CollectionEntity> { collection in
            collection.isDefault == true
        }
        
        do {
            let defaultCollections = try modelContext.fetch(FetchDescriptor<CollectionEntity>(predicate: predicate))
            if defaultCollections.isEmpty {
                // Create default collection
                let favorites = CollectionEntity(name: "Favorites", isDefault: true)
                modelContext.insert(favorites)
                
                // Create "My Collection" as well
                let myCollection = CollectionEntity(name: "My Collection")
                modelContext.insert(myCollection)
                
                saveChanges()
                defaultCollection = favorites
            } else {
                defaultCollection = defaultCollections.first
            }
        } catch {
            logger.error("Failed to initialize default collection: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Card Operations
    
    /// Adds a card to the user's collection
    /// - Parameter card: The card to add
    /// - Returns: The saved CardEntity
    @discardableResult
    func addCard(_ card: Card) -> CardEntity {
        // Check if card already exists
        if let existingCard = fetchCard(withID: card.id) {
            // Increment quantity
            existingCard.quantity += 1
            saveChanges()
            return existingCard
        } else {
            // Create new card entity
            let cardEntity = CardEntity(from: card)
            modelContext.insert(cardEntity)
            saveChanges()
            return cardEntity
        }
    }
    
    /// Updates a card in the user's collection
    /// - Parameter cardEntity: The card entity to update
    func updateCard(_ cardEntity: CardEntity) {
        saveChanges()
    }
    
    /// Removes a card from the user's collection
    /// - Parameter cardEntity: The card entity to remove
    func removeCard(_ cardEntity: CardEntity) {
        modelContext.delete(cardEntity)
        saveChanges()
    }
    
    /// Decreases the quantity of a card in the collection
    /// - Parameter cardEntity: The card entity to update
    /// - Returns: True if the card was completely removed, false if only quantity was decreased
    @discardableResult
    func decreaseCardQuantity(_ cardEntity: CardEntity) -> Bool {
        if cardEntity.quantity > 1 {
            cardEntity.quantity -= 1
            saveChanges()
            return false
        } else {
            removeCard(cardEntity)
            return true
        }
    }
    
    /// Fetches a card by its ID
    /// - Parameter id: The card ID to fetch
    /// - Returns: The card entity if found, nil otherwise
    func fetchCard(withID id: String) -> CardEntity? {
        let predicate = #Predicate<CardEntity> { card in
            card.id == id
        }
        
        do {
            let cards = try modelContext.fetch(FetchDescriptor<CardEntity>(predicate: predicate))
            return cards.first
        } catch {
            logger.error("Failed to fetch card with ID \(id): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Fetches all cards in the user's collection
    /// - Returns: An array of card entities
    func fetchAllCards() -> [CardEntity] {
        do {
            return try modelContext.fetch(FetchDescriptor<CardEntity>())
        } catch {
            logger.error("Failed to fetch all cards: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches cards with a specific filter
    /// - Parameter predicate: The predicate to filter cards
    /// - Returns: An array of filtered card entities
    func fetchCards(matching predicate: Predicate<CardEntity>) -> [CardEntity] {
        do {
            let descriptor = FetchDescriptor<CardEntity>(predicate: predicate)
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch cards with predicate: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Toggles the favorite status of a card
    /// - Parameter cardEntity: The card entity to update
    func toggleFavorite(_ cardEntity: CardEntity) {
        cardEntity.isFavorite.toggle()
        saveChanges()
    }
    
    /// Updates the price of a card
    /// - Parameters:
    ///   - cardEntity: The card entity to update
    ///   - price: The new price
    func updatePrice(for cardEntity: CardEntity, price: Double) {
        cardEntity.currentPrice = price
        cardEntity.priceLastUpdated = Date()
        saveChanges()
    }
    
    // MARK: - Collection Management
    
    /// Fetches all collections
    /// - Returns: An array of collection entities
    func fetchAllCollections() -> [CollectionEntity] {
        do {
            let descriptor = FetchDescriptor<CollectionEntity>(sortBy: [SortDescriptor(\.dateCreated, order: .reverse)])
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch collections: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Creates a new collection
    /// - Parameter name: The name of the collection
    /// - Returns: The created collection entity
    @discardableResult
    func createCollection(name: String, imageURL: String? = nil) -> CollectionEntity {
        let collection = CollectionEntity(name: name, imageURL: imageURL)
        modelContext.insert(collection)
        saveChanges()
        return collection
    }
    
    /// Deletes a collection
    /// - Parameter collection: The collection to delete
    func deleteCollection(_ collection: CollectionEntity) {
        // Don't delete the default collection
        if collection.isDefault {
            return
        }
        
        modelContext.delete(collection)
        saveChanges()
    }
    
    /// Updates a collection
    /// - Parameter collection: The collection to update
    func updateCollection(_ collection: CollectionEntity) {
        saveChanges()
    }
    
    /// Adds a card to a collection
    /// - Parameters:
    ///   - card: The card to add
    ///   - collection: The collection to add the card to
    /// - Returns: The card entity
    @discardableResult
    func addCard(_ card: Card, to collection: CollectionEntity? = nil) -> CardEntity {
        // Get the target collection (default if none specified)
        let targetCollection = collection ?? defaultCollection ?? {
            let defaultCollection = createCollection(name: "Favorites", imageURL: nil)
            defaultCollection.isDefault = true
            return defaultCollection
        }()
        
        // Check if card already exists in the collection
        let existingCard = targetCollection.cards.first { $0.id == card.id }
        
        if let existingCard = existingCard {
            // Increment quantity
            existingCard.quantity += 1
            saveChanges()
            return existingCard
        } else {
            // Create new card entity
            let cardEntity = CardEntity(from: card)
            modelContext.insert(cardEntity)
            
            // Add to collection
            targetCollection.cards.append(cardEntity)
            saveChanges()
            return cardEntity
        }
    }
    
    /// Moves a card from one collection to another
    /// - Parameters:
    ///   - card: The card to move
    ///   - sourceCollection: The source collection
    ///   - destinationCollection: The destination collection
    func moveCard(_ card: CardEntity, from sourceCollection: CollectionEntity, to destinationCollection: CollectionEntity) {
        // Remove from source collection
        sourceCollection.cards.removeAll { $0.id == card.id }
        
        // Add to destination collection
        destinationCollection.cards.append(card)
        saveChanges()
    }
    
    /// Checks if a card is in a specific collection
    /// - Parameters:
    ///   - cardId: The ID of the card
    ///   - collection: The collection to check
    /// - Returns: True if the card is in the collection, false otherwise
    func isCardInCollection(_ cardId: String, in collection: CollectionEntity) -> Bool {
        return collection.cards.contains { $0.id == cardId }
    }
    
    // MARK: - Helper Methods
    
    /// Saves any pending changes to the persistent store
    private func saveChanges() {
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save changes: \(error.localizedDescription)")
        }
    }
} 