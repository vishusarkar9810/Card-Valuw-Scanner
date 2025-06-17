import Foundation
import SwiftData

@Model
final class CardEntity {
    var id: String
    var name: String
    var supertype: String
    var imageSmallURL: String
    var imageLargeURL: String
    var types: [String]
    var rarity: String?
    var setID: String?
    var setName: String?
    var number: String?
    var artist: String?
    var currentPrice: Double?
    var priceLastUpdated: Date?
    var dateAdded: Date
    var isFavorite: Bool
    var quantity: Int
    
    init(
        id: String,
        name: String,
        supertype: String,
        imageSmallURL: String,
        imageLargeURL: String,
        types: [String] = [],
        rarity: String? = nil,
        setID: String? = nil,
        setName: String? = nil,
        number: String? = nil,
        artist: String? = nil,
        currentPrice: Double? = nil,
        priceLastUpdated: Date? = nil,
        dateAdded: Date = Date(),
        isFavorite: Bool = false,
        quantity: Int = 1
    ) {
        self.id = id
        self.name = name
        self.supertype = supertype
        self.imageSmallURL = imageSmallURL
        self.imageLargeURL = imageLargeURL
        self.types = types
        self.rarity = rarity
        self.setID = setID
        self.setName = setName
        self.number = number
        self.artist = artist
        self.currentPrice = currentPrice
        self.priceLastUpdated = priceLastUpdated
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
        self.quantity = quantity
    }
    
    // Convenience initializer to create a CardEntity from a Card model
    convenience init(from card: Card) {
        self.init(
            id: card.id,
            name: card.name,
            supertype: card.supertype,
            imageSmallURL: card.images.small,
            imageLargeURL: card.images.large,
            types: card.types ?? [],
            rarity: nil, // Add this if available in Card model
            setID: nil, // Add this if available in Card model
            setName: nil, // Add this if available in Card model
            number: nil, // Add this if available in Card model
            artist: nil, // Add this if available in Card model
            currentPrice: card.tcgplayer?.prices?.normal?.market ?? 
                         card.tcgplayer?.prices?.holofoil?.market ?? 
                         card.tcgplayer?.prices?.reverseHolofoil?.market
        )
    }
}

// Extension to convert CardEntity back to Card model if needed
extension CardEntity {
    func toCard() -> Card {
        let cardImages = CardImages(small: imageSmallURL, large: imageLargeURL)
        
        // Create price details if available
        var priceDetails: PriceDetails? = nil
        if let price = currentPrice {
            priceDetails = PriceDetails(low: nil, mid: nil, high: nil, market: price, directLow: nil)
        }
        
        // Create prices if available
        var prices: Prices? = nil
        if let priceDetails = priceDetails {
            prices = Prices(normal: priceDetails, holofoil: nil, reverseHolofoil: nil)
        }
        
        // Create TCGPlayer if available
        var tcgPlayer: TcgPlayer? = nil
        if let prices = prices {
            tcgPlayer = TcgPlayer(url: "", updatedAt: "", prices: prices)
        }
        
        return Card(
            id: id,
            name: name,
            supertype: supertype,
            subtypes: nil,
            hp: nil,
            types: types.isEmpty ? nil : types,
            evolvesFrom: nil,
            evolvesTo: nil,
            rules: nil,
            images: cardImages,
            tcgplayer: tcgPlayer,
            cardmarket: nil
        )
    }
} 