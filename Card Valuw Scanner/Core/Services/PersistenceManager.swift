import Foundation
import SwiftData
import OSLog

/// A service class that manages persistence operations for the app's data
@Observable
final class PersistenceManager {
    private let logger = Logger(subsystem: "com.app.cardvaluescanner", category: "PersistenceManager")
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.debug("Successfully initialized PersistenceManager with ModelContext")
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
    
    /// Checks if a card is in the user's collection
    /// - Parameter cardId: The ID of the card to check
    /// - Returns: True if the card is in the collection, false otherwise
    func isCardInCollection(cardId: String) -> Bool {
        return fetchCard(withID: cardId) != nil
    }
    
    /// Adds a card to the user's collection
    /// - Parameter card: The card to add to the collection
    func addCardToCollection(card: Card) {
        _ = addCard(card)
    }
    
    /// Removes a card from the user's collection by ID
    /// - Parameter cardId: The ID of the card to remove
    func removeCardFromCollection(cardId: String) {
        if let cardEntity = fetchCard(withID: cardId) {
            removeCard(cardEntity)
        }
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