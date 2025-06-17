import Foundation
import UIKit
import SwiftUI

@Observable
final class ScannerViewModel {
    // MARK: - Properties
    
    private let cardScannerService: CardScannerService
    private let pokemonTCGService: PokemonTCGService
    private var persistenceManager: PersistenceManager
    
    // State
    var isScanning = false
    var isProcessing = false
    var scanResult: Card? = nil
    var errorMessage: String? = nil
    var addedToCollection = false
    var debugInfo: String? = nil // For debugging purposes
    
    // MARK: - Initialization
    
    init(cardScannerService: CardScannerService, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.cardScannerService = cardScannerService
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
    }
    
    // MARK: - Methods
    
    /// Update the persistence manager
    /// - Parameter newPersistenceManager: The new persistence manager
    func updatePersistenceManager(_ newPersistenceManager: PersistenceManager) {
        self.persistenceManager = newPersistenceManager
    }
    
    /// Process the captured image to identify the card
    /// - Parameter image: The captured image
    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        debugInfo = nil
        addedToCollection = false
        
        do {
            // Step 1: Identify card from image
            let cardInfo = await cardScannerService.identifyCard(from: image)
            
            // Debug info
            debugInfo = "Extracted info: \(cardInfo)"
            
            // Step 2: Search for the card using the extracted info
            if let cardName = cardInfo["name"] {
                // Try to search by name
                let query = ["q": "name:\"\(cardName)\"", "page": "1", "pageSize": "10"]
                let response = try await pokemonTCGService.searchCards(query: query)
                
                if let firstCard = response.data.first {
                    scanResult = firstCard
                } else {
                    // If no exact match, try a more fuzzy search
                    let fuzzyQuery = ["q": "name:*\(cardName)*", "page": "1", "pageSize": "10"]
                    let fuzzyResponse = try await pokemonTCGService.searchCards(query: fuzzyQuery)
                    
                    if let firstCard = fuzzyResponse.data.first {
                        scanResult = firstCard
                    } else {
                        errorMessage = "No matching card found for '\(cardName)'. Try taking a clearer photo."
                    }
                }
            } else if let cardNumber = cardInfo["number"] {
                // Try to search by card number if name is not available
                let query = ["q": "number:\(cardNumber)", "page": "1", "pageSize": "10"]
                let response = try await pokemonTCGService.searchCards(query: query)
                
                if let firstCard = response.data.first {
                    scanResult = firstCard
                } else {
                    errorMessage = "Could not find card with number \(cardNumber). Try taking a clearer photo."
                }
            } else {
                errorMessage = "Could not identify card from image. Make sure the card is well-lit and clearly visible."
            }
        } catch let error as NSError {
            if error.domain == NSURLErrorDomain {
                errorMessage = "Network error: Please check your internet connection and try again."
            } else {
                errorMessage = "Error: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    /// Reset the scanner state
    func reset() {
        scanResult = nil
        errorMessage = nil
        debugInfo = nil
        isProcessing = false
        addedToCollection = false
    }
    
    /// Add the scanned card to collection
    /// - Returns: Boolean indicating success
    func addToCollection() -> Bool {
        guard let card = scanResult else {
            return false
        }
        
        // Add the card to the persistent store
        let _ = persistenceManager.addCard(card)
        addedToCollection = true
        return true
    }
} 