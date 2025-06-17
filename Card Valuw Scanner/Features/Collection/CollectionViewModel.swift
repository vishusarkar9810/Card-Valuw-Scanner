import Foundation
import SwiftUI
import Observation

@Observable
final class CollectionViewModel {
    // MARK: - Properties
    
    private let pokemonTCGService: PokemonTCGService
    
    // State
    var cards: [Card] = []
    var isLoading = false
    var errorMessage: String? = nil
    
    // Filters
    var searchText = ""
    var selectedTypes: [String] = []
    var selectedSets: [String] = []
    
    // MARK: - Initialization
    
    init(pokemonTCGService: PokemonTCGService) {
        self.pokemonTCGService = pokemonTCGService
    }
    
    // MARK: - Methods
    
    /// Load sample cards for demo purposes
    func loadSampleCards() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Sample search for popular Pokemon
            let query = ["q": "name:pikachu OR name:charizard OR name:mewtwo", "page": "1", "pageSize": "20"]
            let response = try await pokemonTCGService.searchCards(query: query)
            cards = response.data
        } catch {
            errorMessage = "Error loading cards: \(error.localizedDescription)"
        }
        
        isLoading = false
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
        
        for card in cards {
            if let price = card.tcgplayer?.prices?.normal?.market {
                total += price
            } else if let price = card.tcgplayer?.prices?.holofoil?.market {
                total += price
            }
        }
        
        return total
    }
    
    /// Reset all filters
    func resetFilters() {
        searchText = ""
        selectedTypes = []
        selectedSets = []
    }
} 