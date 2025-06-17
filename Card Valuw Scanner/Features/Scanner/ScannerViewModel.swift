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
    
    // Additional state for improved scanning experience
    var potentialMatches: [Card] = []
    var selectedMatchIndex: Int = 0
    var scanAttempts: Int = 0
    var lastScannedImage: UIImage? = nil
    
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
        potentialMatches = []
        selectedMatchIndex = 0
        lastScannedImage = image
        scanAttempts += 1
        
        do {
            // Step 1: Identify card from image
            let cardInfo = await cardScannerService.identifyCard(from: image)
            
            // Debug info
            debugInfo = "Extracted info: \(cardInfo)"
            
            // Step 2: Search for the card using the extracted info
            if let cardName = cardInfo["name"] {
                await searchByName(cardName)
            } else if let cardNumber = cardInfo["number"] {
                await searchByNumber(cardNumber, set: cardInfo["set"])
            } else if let hp = cardInfo["hp"] {
                await searchByHP(hp)
            } else {
                errorMessage = "Could not identify card from image. Make sure the card is well-lit and clearly visible."
            }
            
            // If we have potential matches but no definitive result, set the first match as the result
            if scanResult == nil && !potentialMatches.isEmpty {
                scanResult = potentialMatches[0]
            }
            
        } catch let error as NSError {
            handleError(error)
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    /// Search for cards by name
    /// - Parameter name: The card name to search for
    private func searchByName(_ name: String) async {
        do {
            // Try to search by exact name first
            let exactQuery = ["q": "name:\"\(name)\"", "page": "1", "pageSize": "10"]
            let exactResponse = try await pokemonTCGService.searchCards(query: exactQuery)
            
            if let firstCard = exactResponse.data.first {
                scanResult = firstCard
                potentialMatches = exactResponse.data
                return
            }
            
            // If no exact match, try a fuzzy search
            let fuzzyQuery = ["q": "name:*\(name)*", "page": "1", "pageSize": "20"]
            let fuzzyResponse = try await pokemonTCGService.searchCards(query: fuzzyQuery)
            
            if !fuzzyResponse.data.isEmpty {
                // Store all potential matches
                potentialMatches = fuzzyResponse.data
                
                // Use the first match as the result
                scanResult = fuzzyResponse.data.first
            } else {
                // Try an even more lenient search by splitting the name and searching for parts
                let nameParts = name.split(separator: " ")
                if nameParts.count > 1, let firstPart = nameParts.first {
                    let partQuery = ["q": "name:*\(firstPart)*", "page": "1", "pageSize": "20"]
                    let partResponse = try await pokemonTCGService.searchCards(query: partQuery)
                    
                    if !partResponse.data.isEmpty {
                        potentialMatches = partResponse.data
                        scanResult = partResponse.data.first
                    } else {
                        errorMessage = "No matching card found for '\(name)'. Try taking a clearer photo."
                    }
                } else {
                    errorMessage = "No matching card found for '\(name)'. Try taking a clearer photo."
                }
            }
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
        }
    }
    
    /// Search for cards by number and optionally set
    /// - Parameters:
    ///   - number: The card number
    ///   - set: Optional set identifier
    private func searchByNumber(_ number: String, set: String?) async {
        do {
            var query: [String: Any] = ["page": "1", "pageSize": "10"]
            
            // If we have both number and set, use them together for more accurate results
            if let set = set {
                query["q"] = "number:\(number) set.id:\(set)"
            } else {
                query["q"] = "number:\(number)"
            }
            
            let response = try await pokemonTCGService.searchCards(query: query)
            
            if !response.data.isEmpty {
                potentialMatches = response.data
                scanResult = response.data.first
            } else {
                // Try just the number without the set
                if set != nil {
                    query["q"] = "number:\(number)"
                    let fallbackResponse = try await pokemonTCGService.searchCards(query: query)
                    
                    if !fallbackResponse.data.isEmpty {
                        potentialMatches = fallbackResponse.data
                        scanResult = fallbackResponse.data.first
                    } else {
                        errorMessage = "Could not find card with number \(number). Try taking a clearer photo."
                    }
                } else {
                    errorMessage = "Could not find card with number \(number). Try taking a clearer photo."
                }
            }
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
        }
    }
    
    /// Search for cards by HP value
    /// - Parameter hp: The HP value
    private func searchByHP(_ hp: String) async {
        do {
            // HP is less specific, but we can still try
            let query = ["q": "hp:\(hp)", "page": "1", "pageSize": "20"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            if !response.data.isEmpty {
                potentialMatches = response.data
                // Don't set scanResult yet, as HP is too generic
                // We'll show these as potential matches instead
                errorMessage = "Multiple cards found with HP \(hp). Please select the correct card from the list or try scanning again."
            } else {
                errorMessage = "Could not find cards with HP \(hp). Try taking a clearer photo."
            }
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
        }
    }
    
    /// Handle network and other errors
    /// - Parameter error: The error to handle
    private func handleError(_ error: NSError) {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                errorMessage = "No internet connection. Please connect to the internet and try again."
            case NSURLErrorTimedOut:
                errorMessage = "Request timed out. Please check your internet connection and try again."
            case NSURLErrorCannotConnectToHost:
                errorMessage = "Cannot connect to the server. The service might be down. Please try again later."
            default:
                errorMessage = "Network error: Please check your internet connection and try again."
            }
        } else {
            errorMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    /// Select a different potential match
    /// - Parameter index: The index of the match to select
    func selectMatch(at index: Int) {
        if index >= 0 && index < potentialMatches.count {
            selectedMatchIndex = index
            scanResult = potentialMatches[index]
        }
    }
    
    /// Try to scan again with different processing parameters
    func tryScanAgain() async {
        guard let image = lastScannedImage else {
            errorMessage = "No image available for rescanning."
            return
        }
        
        // Reset state
        isProcessing = true
        errorMessage = nil
        potentialMatches = []
        
        // Try different approach based on previous attempts
        if scanAttempts == 1 {
            // On second attempt, try with different preprocessing
            debugInfo = "Trying second scan approach..."
            await processImage(image)
        } else {
            // Reset scan attempts if we've tried multiple times
            scanAttempts = 0
            errorMessage = "Unable to identify the card after multiple attempts. Try taking a new photo with better lighting and positioning."
            isProcessing = false
        }
    }
    
    /// Reset the scanner state
    func reset() {
        scanResult = nil
        errorMessage = nil
        debugInfo = nil
        isProcessing = false
        addedToCollection = false
        potentialMatches = []
        selectedMatchIndex = 0
        scanAttempts = 0
        lastScannedImage = nil
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