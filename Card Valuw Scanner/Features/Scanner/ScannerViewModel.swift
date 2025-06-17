import Foundation
import UIKit
import SwiftUI

@Observable
final class ScannerViewModel {
    // MARK: - Properties
    
    private let cardScannerService: CardScannerService
    private let pokemonTCGService: PokemonTCGService
    
    // State
    var isScanning = false
    var isProcessing = false
    var scanResult: Card? = nil
    var errorMessage: String? = nil
    
    // MARK: - Initialization
    
    init(cardScannerService: CardScannerService, pokemonTCGService: PokemonTCGService) {
        self.cardScannerService = cardScannerService
        self.pokemonTCGService = pokemonTCGService
    }
    
    // MARK: - Methods
    
    /// Process the captured image to identify the card
    /// - Parameter image: The captured image
    func processImage(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            // Step 1: Identify card from image
            let cardInfo = await cardScannerService.identifyCard(from: image)
            
            // Step 2: Search for the card using the extracted info
            if let cardName = cardInfo["name"] {
                let query = ["q": "name:\"\(cardName)\"", "page": "1", "pageSize": "10"]
                let response = try await pokemonTCGService.searchCards(query: query)
                
                if let firstCard = response.data.first {
                    scanResult = firstCard
                } else {
                    errorMessage = "No matching card found"
                }
            } else {
                errorMessage = "Could not identify card name from image"
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
        isProcessing = false
    }
    
    /// Add the scanned card to collection
    /// - Returns: Boolean indicating success
    func addToCollection() -> Bool {
        if scanResult != nil {
            // In a real app, we would add this card to a persistent store
            // For now, we'll just return true to simulate success
            return true
        }
        return false
    }
} 