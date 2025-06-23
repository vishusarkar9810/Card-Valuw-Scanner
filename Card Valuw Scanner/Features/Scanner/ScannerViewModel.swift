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
        case hpSearch         // Try searching by HP
        case visualSearch     // Try searching by visual features
        case failed           // All attempts failed
    }
    
    // MARK: - Initialization
    
    init(cardScannerService: CardScannerService, pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self.cardScannerService = cardScannerService
        self.pokemonTCGService = pokemonTCGService
        self.persistenceManager = persistenceManager
    }
    
    /// Convenience initializer with just persistence manager
    /// - Parameter persistenceManager: The persistence manager to use
    convenience init(persistenceManager: PersistenceManager) {
        self.init(
            cardScannerService: CardScannerService(),
            pokemonTCGService: PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey),
            persistenceManager: persistenceManager
        )
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
            
            // Step 3: Search for the card using the extracted info with combined strategies
            var foundCard = false
            
            // Check if we have a high-confidence name extraction
            if let cardName = cardInfo["name"], let confidenceStr = cardInfo["nameConfidence"], 
               let confidence = Float(confidenceStr), confidence > 7.0 {
                // High confidence name extraction - prioritize this search
                scanStage = .nameSearch
                
                // If we also have HP, use combined search
                if let cardHP = cardInfo["hp"] {
                    foundCard = await searchByNameAndHP(name: cardName, hp: cardHP)
                    
                    // If combined search fails, try name-only
                    if !foundCard {
                        foundCard = await searchByName(cardName)
                    }
                } else {
                    // No HP, use name-only search
                    foundCard = await searchByName(cardName)
                }
            } 
            // If high-confidence name extraction failed, try the regular combined search
            else if let cardName = cardInfo["name"], let cardHP = cardInfo["hp"] {
                // If we have a nameHPConfidence value, this is our highest priority search
                if let _ = cardInfo["nameHPConfidence"] {
                    scanStage = .nameSearch
                    foundCard = await searchByNameAndHP(name: cardName, hp: cardHP)
                    
                    // If this high-confidence search fails, something is wrong with the data
                    if !foundCard {
                        // Try with just the name as fallback
                        foundCard = await searchByName(cardName)
                    }
                } else {
                    // Standard name+HP search
                    foundCard = await searchByNameAndHP(name: cardName, hp: cardHP)
                }
            }
            
            // If name+HP search failed, try combined search with name and number
            if !foundCard, let cardName = cardInfo["name"], let cardNumber = cardInfo["number"] {
                scanStage = .numberSearch
                foundCard = await searchByNameAndNumber(name: cardName, number: cardNumber, set: cardInfo["set"])
            }
            
            // If combined searches failed, try by name (still quite accurate)
            if !foundCard, let cardName = cardInfo["name"] {
                scanStage = .nameSearch
                foundCard = await searchByName(cardName)
            }
            
            // If name search failed, try by number and set
            if !foundCard, let cardNumber = cardInfo["number"] {
                scanStage = .numberSearch
                foundCard = await searchByNumber(cardNumber, set: cardInfo["set"])
            }
            
            // If other searches failed, try by HP (less specific)
            if !foundCard, let hp = cardInfo["hp"] {
                scanStage = .hpSearch
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
    
    /// Combined search by name and number for highest accuracy
    /// - Parameters:
    ///   - name: The card name
    ///   - number: The card number
    ///   - set: Optional set identifier
    /// - Returns: Boolean indicating if search was successful
    private func searchByNameAndNumber(name: String, number: String, set: String?) async -> Bool {
        do {
            // Build a combined query with both name and number
            var queryString = "name:*\(name)* number:\(number)"
            
            // Add set if available
            if let set = set {
                queryString += " set.id:\(set)"
            }
            
            let query = ["q": queryString, "page": "1", "pageSize": "10"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            if !response.data.isEmpty {
                // Calculate relevance scores for each card
                var scoredMatches = response.data.map { card -> (card: Card, score: Int) in
                    var score = 0
                    
                    // Exact name match is highest priority
                    if card.name.lowercased() == name.lowercased() {
                        score += 10
                    }
                    // Partial name match
                    else if card.name.lowercased().contains(name.lowercased()) {
                        score += 5
                    }
                    
                    // Exact number match
                    if card.number == number {
                        score += 8
                    }
                    
                    // Set match if we have one
                    if let set = set, card.set?.id.lowercased() == set.lowercased() {
                        score += 6
                    }
                    
                    return (card, score)
                }
                
                // Sort by score
                scoredMatches.sort { $0.score > $1.score }
                
                // Use the highest scored match
                potentialMatches = scoredMatches.map { $0.card }
                scanResult = potentialMatches.first
                return true
            }
            
            return false
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Search for cards by name
    /// - Parameter name: The card name to search for
    /// - Returns: Boolean indicating if search was successful
    private func searchByName(_ name: String) async -> Bool {
        do {
            // Clean the name - remove any non-alphanumeric characters except spaces
            let cleanName = name.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ")).inverted).joined()
            
            // Try to search by exact name first
            let exactQuery = ["q": "name:\"\(cleanName)\"", "page": "1", "pageSize": "10"]
            let exactResponse = try await pokemonTCGService.searchCards(query: exactQuery)
            
            if let firstCard = exactResponse.data.first {
                scanResult = firstCard
                potentialMatches = exactResponse.data
                return true
            }
            
            // If no exact match, try a fuzzy search
            let fuzzyQuery = ["q": "name:*\(cleanName)*", "page": "1", "pageSize": "20"]
            let fuzzyResponse = try await pokemonTCGService.searchCards(query: fuzzyQuery)
            
            if !fuzzyResponse.data.isEmpty {
                // Calculate relevance scores for each card
                var scoredMatches = fuzzyResponse.data.map { card -> (card: Card, score: Int) in
                    var score = 0
                    
                    // Exact name match is highest priority
                    if card.name.lowercased() == cleanName.lowercased() {
                        score += 10
                    }
                    // Name starts with our search term
                    else if card.name.lowercased().starts(with: cleanName.lowercased()) {
                        score += 7
                    }
                    // Name contains our search term
                    else if card.name.lowercased().contains(cleanName.lowercased()) {
                        score += 5
                    }
                    
                    // Prefer newer cards (they tend to be more relevant)
                    if let set = card.set {
                        // More recent cards get higher scores
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy/MM/dd"
                        if let releaseDate = set.releaseDate, let date = dateFormatter.date(from: releaseDate) {
                            let now = Date()
                            let timeInterval = now.timeIntervalSince(date)
                            // Cards from the last 2 years get a bonus
                            if timeInterval < 60*60*24*365*2 { // 2 years in seconds
                                score += 3
                            }
                        }
                    }
                    
                    return (card, score)
                }
                
                // Sort by score
                scoredMatches.sort { $0.score > $1.score }
                
                // Use the highest scored match
                potentialMatches = scoredMatches.map { $0.card }
                scanResult = potentialMatches.first
                return true
            } else {
                // Try an even more lenient search by splitting the name and searching for parts
                let nameParts = cleanName.split(separator: " ")
                if nameParts.count > 1, let firstPart = nameParts.first {
                    let partQuery = ["q": "name:*\(firstPart)*", "page": "1", "pageSize": "20"]
                    let partResponse = try await pokemonTCGService.searchCards(query: partQuery)
                    
                    if !partResponse.data.isEmpty {
                        // Calculate relevance scores for each card
                        var scoredMatches = partResponse.data.map { card -> (card: Card, score: Int) in
                            var score = 0
                            
                            // Check how many name parts match
                            let cardNameLower = card.name.lowercased()
                            var matchedParts = 0
                            
                            for part in nameParts {
                                if cardNameLower.contains(part.lowercased()) {
                                    matchedParts += 1
                                }
                            }
                            
                            // Score based on percentage of parts matched
                            let matchPercentage = Double(matchedParts) / Double(nameParts.count)
                            score += Int(matchPercentage * 10)
                            
                            return (card, score)
                        }
                        
                        // Sort by score
                        scoredMatches.sort { $0.score > $1.score }
                        
                        // Use the highest scored match
                        potentialMatches = scoredMatches.map { $0.card }
                        scanResult = potentialMatches.first
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
                // Calculate relevance scores for each card
                var scoredMatches = response.data.map { card -> (card: Card, score: Int) in
                    var score = 0
                    
                    // Exact HP match is highest priority
                    if card.hp == hp {
                        score += 10
                    } else {
                        // If not exact match, calculate how close the HP values are
                        if let cardHP = Int(card.hp ?? "0"), let searchHP = Int(hp) {
                            let difference = abs(cardHP - searchHP)
                            if difference <= 10 {
                                // Very close match
                                score += 8
                            } else if difference <= 30 {
                                // Somewhat close match
                                score += 5
                            } else if difference <= 50 {
                                // Distant match
                                score += 2
                            }
                        }
                    }
                    
                    // Prefer newer cards (they tend to be more relevant)
                    if let set = card.set {
                        // More recent cards get higher scores
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy/MM/dd"
                        if let releaseDate = set.releaseDate, let date = dateFormatter.date(from: releaseDate) {
                            let now = Date()
                            let timeInterval = now.timeIntervalSince(date)
                            // Cards from the last 2 years get a bonus
                            if timeInterval < 60*60*24*365*2 { // 2 years in seconds
                                score += 3
                            }
                        }
                    }
                    
                    // Prefer certain card types that are more popular
                    if let types = card.types {
                        let popularTypes = ["Fire", "Water", "Electric", "Psychic", "Dragon"]
                        for type in types {
                            if popularTypes.contains(type) {
                                score += 1
                                break
                            }
                        }
                    }
                    
                    return (card, score)
                }
                
                // Sort by score
                scoredMatches.sort { $0.score > $1.score }
                
                // Use the highest scored match
                potentialMatches = scoredMatches.map { $0.card }
                scanResult = potentialMatches.first
                
                // If we have a high-confidence match, return true
                if let topScore = scoredMatches.first?.score, topScore >= 8 {
                    return true
                }
                
                // Otherwise, we'll show these as potential matches
                errorMessage = "Multiple cards found with HP \(hp). Please select the correct card from the list or try scanning again."
                return false // Return false since we need user intervention
            }
            
            return false
        } catch {
            errorMessage = "Error searching for card: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Search for cards by combining name and HP for higher accuracy
    /// - Parameters:
    ///   - name: The card name
    ///   - hp: The HP value
    /// - Returns: Boolean indicating if search was successful
    private func searchByNameAndHP(name: String, hp: String) async -> Bool {
        do {
            // Clean the name - remove any non-alphanumeric characters except spaces
            let cleanName = name.components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " ")).inverted).joined()
            
            // Build a query that combines both name and HP
            let query = ["q": "name:*\(cleanName)* hp:\(hp)", "page": "1", "pageSize": "20"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            if !response.data.isEmpty {
                // Calculate relevance scores for each card
                var scoredMatches = response.data.map { card -> (card: Card, score: Int) in
                    var score = 0
                    
                    // Name matching - more precise matching for better results
                    if card.name.lowercased() == cleanName.lowercased() {
                        score += 10 // Exact name match
                    } else if card.name.lowercased().starts(with: cleanName.lowercased()) {
                        score += 7 // Name starts with our search term
                    } else if card.name.lowercased().contains(cleanName.lowercased()) {
                        score += 5 // Name contains our search term
                    } else {
                        // Check if name parts match
                        let searchParts = cleanName.lowercased().split(separator: " ")
                        let cardNameParts = card.name.lowercased().split(separator: " ")
                        
                        var matchedParts = 0
                        for part in searchParts {
                            if cardNameParts.contains(where: { $0.contains(part) }) {
                                matchedParts += 1
                            }
                        }
                        
                        if matchedParts > 0 {
                            // Score based on percentage of parts matched
                            let matchPercentage = Double(matchedParts) / Double(searchParts.count)
                            score += Int(matchPercentage * 5)
                        }
                    }
                    
                    // HP matching - exact match is critical
                    if card.hp == hp {
                        score += 10 // Exact HP match
                    } else {
                        // If not exact match, calculate how close the HP values are
                        if let cardHP = Int(card.hp ?? "0"), let searchHP = Int(hp) {
                            let difference = abs(cardHP - searchHP)
                            if difference <= 10 {
                                score += 8 // Very close match
                            } else if difference <= 30 {
                                score += 5 // Somewhat close match
                            } else if difference <= 50 {
                                score += 2 // Distant match
                            }
                        }
                    }
                    
                    // Prefer newer cards
                    if let set = card.set {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy/MM/dd"
                        if let releaseDate = set.releaseDate, let date = dateFormatter.date(from: releaseDate) {
                            let now = Date()
                            let timeInterval = now.timeIntervalSince(date)
                            if timeInterval < 60*60*24*365*2 { // 2 years in seconds
                                score += 3
                            }
                        }
                    }
                    
                    // Prefer certain card types that are more popular
                    if let types = card.types {
                        let popularTypes = ["Fire", "Water", "Electric", "Psychic", "Dragon"]
                        for type in types {
                            if popularTypes.contains(type) {
                                score += 1
                                break
                            }
                        }
                    }
                    
                    return (card, score)
                }
                
                // Sort by score
                scoredMatches.sort { $0.score > $1.score }
                
                // Use the highest scored match
                potentialMatches = scoredMatches.map { $0.card }
                scanResult = potentialMatches.first
                
                // If we have a high-confidence match, return true
                if let topScore = scoredMatches.first?.score, topScore >= 15 {
                    return true
                } else if !potentialMatches.isEmpty {
                    // We have matches but not high confidence
                    return true
                }
            }
            
            // Try a more flexible search if the first one failed
            // This helps with OCR errors in the name
            let nameParts = cleanName.split(separator: " ")
            if nameParts.count > 1, let firstPart = nameParts.first {
                let flexibleQuery = ["q": "name:*\(firstPart)* hp:\(hp)", "page": "1", "pageSize": "20"]
                let flexibleResponse = try await pokemonTCGService.searchCards(query: flexibleQuery)
                
                if !flexibleResponse.data.isEmpty {
                    // Calculate relevance scores for each card
                    var scoredMatches = flexibleResponse.data.map { card -> (card: Card, score: Int) in
                        var score = 0
                        
                        // Name matching
                        let searchParts = cleanName.lowercased().split(separator: " ")
                        let cardNameParts = card.name.lowercased().split(separator: " ")
                        
                        var matchedParts = 0
                        for part in searchParts {
                            if cardNameParts.contains(where: { $0.contains(part) }) {
                                matchedParts += 1
                            }
                        }
                        
                        // Score based on percentage of parts matched
                        let matchPercentage = Double(matchedParts) / Double(searchParts.count)
                        score += Int(matchPercentage * 7)
                        
                        // HP matching - exact match is critical
                        if card.hp == hp {
                            score += 10 // Exact HP match
                        } else {
                            // If not exact match, calculate how close the HP values are
                            if let cardHP = Int(card.hp ?? "0"), let searchHP = Int(hp) {
                                let difference = abs(cardHP - searchHP)
                                if difference <= 10 {
                                    score += 8 // Very close match
                                } else if difference <= 30 {
                                    score += 5 // Somewhat close match
                                } else if difference <= 50 {
                                    score += 2 // Distant match
                                }
                            }
                        }
                        
                        // Prefer newer cards
                        if let set = card.set {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy/MM/dd"
                            if let releaseDate = set.releaseDate, let date = dateFormatter.date(from: releaseDate) {
                                let now = Date()
                                let timeInterval = now.timeIntervalSince(date)
                                if timeInterval < 60*60*24*365*2 { // 2 years in seconds
                                    score += 3
                                }
                            }
                        }
                        
                        return (card, score)
                    }
                    
                    // Sort by score
                    scoredMatches.sort { $0.score > $1.score }
                    
                    // Use the highest scored match
                    potentialMatches = scoredMatches.map { $0.card }
                    scanResult = potentialMatches.first
                    return true
                }
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
    
    /// Search for cards using visual similarity when text recognition fails
    /// - Parameter image: The card image
    /// - Returns: Boolean indicating if search was successful
    private func searchByVisualSimilarity(_ image: UIImage) async -> Bool {
        do {
            // Extract visual features from the scanned image
            let cardFeatures = cardScannerService.extractVisualFeatures(from: image)
            
            // We need to get a set of candidate cards to compare against
            // Start with a broad search to get a set of potential matches
            let query = ["page": "1", "pageSize": "20"]
            let response = try await pokemonTCGService.searchCards(query: query)
            
            if response.data.isEmpty {
                return false
            }
            
            // Create a cache for downloaded images to avoid re-downloading
            var imageCache: [String: UIImage] = [:]
            
            // Download and compare each card image
            var scoredMatches: [(card: Card, score: Float)] = []
            
            for card in response.data {
                guard let imageUrl = URL(string: card.images.small) else { continue }
                
                // Download the card image (with basic caching)
                let cardImage: UIImage
                if let cachedImage = imageCache[card.id] {
                    cardImage = cachedImage
                } else {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: imageUrl)
                        guard let downloadedImage = UIImage(data: data) else { continue }
                        imageCache[card.id] = downloadedImage
                        cardImage = downloadedImage
                    } catch {
                        continue // Skip this card if download fails
                    }
                }
                
                // Extract features from the downloaded card
                let downloadedCardFeatures = cardScannerService.extractVisualFeatures(from: cardImage)
                
                // Compare features
                let similarityScore = cardScannerService.compareVisualFeatures(cardFeatures, downloadedCardFeatures)
                
                // Add to scored matches if similarity is above threshold
                if similarityScore > 0.6 { // Adjust threshold as needed
                    scoredMatches.append((card, similarityScore))
                }
            }
            
            // Sort by similarity score
            scoredMatches.sort { $0.score > $1.score }
            
            // Use the highest scored matches
            potentialMatches = scoredMatches.map { $0.card }
            
            if !potentialMatches.isEmpty {
                scanResult = potentialMatches.first
                return true
            }
            
            return false
        } catch {
            errorMessage = "Error during visual search: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Try scanning again with a different approach
    func tryScanAgain() async {
        guard let image = lastScannedImage else {
            errorMessage = "No image to rescan"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        // Advance to the next scan stage
        switch scanStage {
        case .initial:
            scanStage = .enhancedText
        case .enhancedText:
            scanStage = .nameSearch
        case .nameSearch:
            scanStage = .numberSearch
        case .numberSearch:
            scanStage = .hpSearch
        case .hpSearch:
            scanStage = .visualSearch
        case .visualSearch:
            scanStage = .failed
        case .failed:
            scanStage = .initial
        }
        
        do {
            // Different processing based on scan stage
            switch scanStage {
            case .enhancedText:
                // Try with enhanced contrast and sharpening
                let croppedImage = cardScannerService.preprocessImage(image, strategy: .enhanced)
                let cardInfo = await cardScannerService.identifyCard(from: croppedImage)
                debugInfo = "Enhanced scan: \(cardInfo)"
                
                if let name = cardInfo["name"] {
                    if await searchByName(name) {
                        isProcessing = false
                        return
                    }
                }
                
                if let number = cardInfo["number"] {
                    if await searchByNumber(number, set: cardInfo["set"]) {
                        isProcessing = false
                        return
                    }
                }
            
            case .nameSearch:
                // Try focusing on just the card name at the top
                let croppedImage = cardScannerService.preprocessImage(image, strategy: .topSection)
                let cardInfo = await cardScannerService.identifyCard(from: croppedImage)
                debugInfo = "Name search: \(cardInfo)"
                
                if let name = cardInfo["name"] {
                    if await searchByName(name) {
                        isProcessing = false
                        return
                    }
                }
            
            case .numberSearch:
                // Try focusing on the bottom of the card for the number
                let croppedImage = cardScannerService.detectAndCropCard(image)
                let cardInfo = await cardScannerService.identifyCard(from: croppedImage)
                debugInfo = "Number search: \(cardInfo)"
                
                if let number = cardInfo["number"] {
                    if await searchByNumber(number, set: nil) {
                        isProcessing = false
                        return
                    }
                }
            
            case .hpSearch:
                // Try focusing on the HP value
                let croppedImage = cardScannerService.preprocessImage(image, strategy: .hpSection)
                let cardInfo = await cardScannerService.identifyCard(from: croppedImage)
                debugInfo = "HP search: \(cardInfo)"
                
                if let hp = cardInfo["hp"] {
                    if await searchByHP(hp) {
                        isProcessing = false
                        return
                    }
                }
            
            case .visualSearch:
                // Try visual similarity search when text recognition fails
                debugInfo = "Visual search: Comparing image features"
                let croppedImage = cardScannerService.detectAndCropCard(image)
                
                if await searchByVisualSimilarity(croppedImage) {
                    isProcessing = false
                    return
                }
            
            case .initial, .failed:
                // Just try the normal process again
                await processImage(image)
                isProcessing = false
                return
            }
            
            // If we got here, we failed to identify the card
            errorMessage = "Could not identify card. Try taking a clearer photo or selecting from the list."
            
            // Add a throw statement to make the catch block reachable
            if errorMessage != nil {
                throw NSError(domain: "CardScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage!])
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
            
            addedToCollection = true
            return true
        } else if let defaultCollection = collections.first(where: { !$0.isDefault }) ?? collections.first {
            // Fallback to any non-default collection if "My Collection" doesn't exist
            let cardEntity = persistenceManager.addCard(card, to: defaultCollection)
            
            // Ensure the card has a price
            if cardEntity.currentPrice == nil {
                // Try to set a price from cardmarket if tcgplayer prices are not available
                if let marketPrice = card.cardmarket?.prices?.averageSellPrice ?? card.cardmarket?.prices?.trendPrice {
                    cardEntity.currentPrice = marketPrice
                    persistenceManager.updateCard(cardEntity)
                }
            }
            
            addedToCollection = true
            return true
        }
        
        return false
    }
} 