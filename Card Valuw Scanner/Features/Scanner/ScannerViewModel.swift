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
    var scanStage: ScanStage = .initial
    
    // MARK: - Enums
    
    /// Represents different stages of the scanning process
    enum ScanStage {
        case initial          // Initial scan
        case enhancedText     // Try with enhanced text recognition
        case nameSearch       // Try searching by name parts
        case numberSearch     // Try searching by number
        case visualSearch     // Try searching by visual features
        case failed           // All attempts failed
    }
    
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
        scanStage = .initial
        
        do {
            // Step 1: Try to detect and crop the card from the image
            let croppedImage = cardScannerService.detectAndCropCard(image)
            
            // Step 2: Identify card from image using improved multi-strategy approach
            let cardInfo = await cardScannerService.identifyCard(from: croppedImage)
            
            // Debug info
            debugInfo = "Extracted info: \(cardInfo)"
            
            // Step 3: Search for the card using the extracted info
            var foundCard = false
            
            // Try searching by name first (most accurate)
            if let cardName = cardInfo["name"] {
                foundCard = await searchByName(cardName)
            }
            
            // If name search failed, try by number and set
            if !foundCard, let cardNumber = cardInfo["number"] {
                foundCard = await searchByNumber(cardNumber, set: cardInfo["set"])
            }
            
            // If both failed, try by HP (less specific)
            if !foundCard, let hp = cardInfo["hp"] {
                foundCard = await searchByHP(hp)
            }
            
            // If all direct searches failed but we have potential matches, use the first match
            if !foundCard && !potentialMatches.isEmpty {
                scanResult = potentialMatches[0]
                foundCard = true
            }
            
            // If everything failed, prepare for retry with different approach
            if !foundCard {
                errorMessage = "Could not identify card from image. Try taking a clearer photo."
                scanStage = .enhancedText // Ready for next attempt
            }
            
            // Check if the card is already in the collection
            if let card = scanResult, let existingCard = persistenceManager.fetchCard(withID: card.id) {
                if existingCard.quantity > 0 {
                    // Card is already in the collection
                    addedToCollection = true
                }
            }
            
            // Add a throw statement to make the catch block reachable
            if scanResult == nil && errorMessage == nil {
                throw NSError(domain: "CardScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown scanning error"])
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
    /// - Returns: Boolean indicating if search was successful
    private func searchByName(_ name: String) async -> Bool {
        do {
            // Try to search by exact name first
            let exactQuery = ["q": "name:\"\(name)\"", "page": "1", "pageSize": "10"]
            let exactResponse = try await pokemonTCGService.searchCards(query: exactQuery)
            
            if let firstCard = exactResponse.data.first {
                scanResult = firstCard
                potentialMatches = exactResponse.data
                return true
            }
            
            // If no exact match, try a fuzzy search
            let fuzzyQuery = ["q": "name:*\(name)*", "page": "1", "pageSize": "20"]
            let fuzzyResponse = try await pokemonTCGService.searchCards(query: fuzzyQuery)
            
            if !fuzzyResponse.data.isEmpty {
                // Store all potential matches
                potentialMatches = fuzzyResponse.data
                
                // Use the first match as the result
                scanResult = fuzzyResponse.data.first
                return true
            } else {
                // Try an even more lenient search by splitting the name and searching for parts
                let nameParts = name.split(separator: " ")
                if nameParts.count > 1, let firstPart = nameParts.first {
                    let partQuery = ["q": "name:*\(firstPart)*", "page": "1", "pageSize": "20"]
                    let partResponse = try await pokemonTCGService.searchCards(query: partQuery)
                    
                    if !partResponse.data.isEmpty {
                        potentialMatches = partResponse.data
                        scanResult = partResponse.data.first
                        return true
                    }
                }
            }
            
            return false
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Search for cards by number and optionally set
    /// - Parameters:
    ///   - number: The card number
    ///   - set: Optional set identifier
    /// - Returns: Boolean indicating if search was successful
    private func searchByNumber(_ number: String, set: String?) async -> Bool {
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
                return true
            } else {
                // Try just the number without the set
                if set != nil {
                    query["q"] = "number:\(number)"
                    let fallbackResponse = try await pokemonTCGService.searchCards(query: query)
                    
                    if !fallbackResponse.data.isEmpty {
                        potentialMatches = fallbackResponse.data
                        scanResult = fallbackResponse.data.first
                        return true
                    }
                }
            }
            
            return false
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Search for cards by HP value
    /// - Parameter hp: The HP value
    /// - Returns: Boolean indicating if search was successful
    private func searchByHP(_ hp: String) async -> Bool {
        do {
            // HP is less specific, but we can still try
            let query = ["q": "hp:\(hp)", "page": "1", "pageSize": "20"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            if !response.data.isEmpty {
                potentialMatches = response.data
                // Don't set scanResult yet, as HP is too generic
                // We'll show these as potential matches instead
                errorMessage = "Multiple cards found with HP \(hp). Please select the correct card from the list or try scanning again."
                return false // Return false since we need user intervention
            }
            
            return false
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
            return false
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
            
            // Check if the newly selected card is already in the collection
            if let card = scanResult, let existingCard = persistenceManager.fetchCard(withID: card.id) {
                if existingCard.quantity > 0 {
                    // Card is already in the collection
                    addedToCollection = true
                } else {
                    addedToCollection = false
                }
            } else {
                addedToCollection = false
            }
        }
    }
    
    /// Select a match directly from a card object
    /// - Parameter card: The card to select as the match
    func selectMatch(_ card: Card) {
        // Find the index of the card in potential matches if it exists
        if let index = potentialMatches.firstIndex(where: { $0.id == card.id }) {
            selectMatch(at: index)
        } else {
            // If the card isn't in potential matches, just set it directly
            scanResult = card
            
            // Check if the card is already in the collection
            if let existingCard = persistenceManager.fetchCard(withID: card.id) {
                if existingCard.quantity > 0 {
                    // Card is already in the collection
                    addedToCollection = true
                } else {
                    addedToCollection = false
                }
            } else {
                addedToCollection = false
            }
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
        
        // Try different approach based on current scan stage
        switch scanStage {
        case .initial:
            // Move to enhanced text recognition
            scanStage = .enhancedText
            debugInfo = "Trying enhanced text recognition..."
            
            // Use enhanced text recognition
            let croppedImage = cardScannerService.detectAndCropCard(image)
            let recognizedText = await cardScannerService.recognizeText(in: croppedImage)
            let cardInfo = cardScannerService.extractCardInfo(from: recognizedText)
            
            debugInfo = "Enhanced scan info: \(cardInfo)"
            
            // Try searching with this enhanced info
            if let name = cardInfo["name"] {
                _ = await searchByName(name)
            } else if let number = cardInfo["number"] {
                _ = await searchByNumber(number, set: cardInfo["set"])
            }
            
        case .enhancedText:
            // Move to name search with partial matching
            scanStage = .nameSearch
            debugInfo = "Trying partial name search..."
            
            // Try to extract any text that might be part of a name
            let croppedImage = cardScannerService.detectAndCropCard(image)
            let recognizedText = await cardScannerService.recognizeText(in: croppedImage)
            
            // Look for potential name fragments
            let potentialNameFragments = recognizedText.filter { text in
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.count >= 3 && cleaned.first?.isUppercase == true
            }
            
            // Try searching for each potential name fragment
            var found = false
            for fragment in potentialNameFragments {
                if await searchByName(fragment) {
                    found = true
                    break
                }
            }
            
            if !found {
                errorMessage = "Still unable to identify the card. Try taking a new photo with better lighting."
            }
            
        case .nameSearch:
            // Move to number search
            scanStage = .numberSearch
            debugInfo = "Trying number pattern search..."
            
            // Look specifically for number patterns
            let croppedImage = cardScannerService.detectAndCropCard(image)
            let recognizedText = await cardScannerService.recognizeText(in: croppedImage)
            
            // Extract anything that looks like a card number
            var found = false
            for text in recognizedText {
                if let range = text.range(of: #"\d+/\d+"#, options: .regularExpression) {
                    let number = String(text[range])
                    if await searchByNumber(number, set: nil) {
                        found = true
                        break
                    }
                }
            }
            
            if !found {
                errorMessage = "Unable to identify the card after multiple attempts. Try taking a new photo with better lighting and positioning."
            }
            
        default:
            // Reset scan attempts if we've tried multiple approaches
            scanAttempts = 0
            scanStage = .initial
            errorMessage = "Unable to identify the card after multiple attempts. Try taking a new photo with better lighting and positioning."
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
        potentialMatches = []
        selectedMatchIndex = 0
        scanAttempts = 0
        lastScannedImage = nil
        scanStage = .initial
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