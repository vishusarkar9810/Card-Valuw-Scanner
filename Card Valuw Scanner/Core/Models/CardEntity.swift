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
    
    // Collection relationship
    @Relationship(inverse: \CollectionEntity.cards)
    var collections: [CollectionEntity] = []
    
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
            rarity: card.subtypes?.first(where: { $0.contains("Rare") || $0.contains("Common") || $0.contains("Uncommon") }),
            setID: card.set?.id,
            setName: card.set?.name,
            number: card.number,
            artist: nil, // Add this if available in Card model
            currentPrice: card.tcgplayer?.prices?.normal?.market ?? 
                         card.tcgplayer?.prices?.holofoil?.market ?? 
                         card.tcgplayer?.prices?.reverseHolofoil?.market ??
                         card.cardmarket?.prices?.averageSellPrice ??
                         card.cardmarket?.prices?.trendPrice
        )
    }
}

// Extension to convert CardEntity back to Card model if needed
extension CardEntity {
    // Increase the quantity of a card
    func increaseQuantity() {
        self.quantity += 1
    }
    
    // Decrease the quantity of a card and return true if it should be removed
    func decreaseQuantity() -> Bool {
        self.quantity -= 1
        return self.quantity <= 0
    }
    
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
            tcgPlayer = TcgPlayer(url: "https://www.tcgplayer.com/search/pokemon/all?q=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)", updatedAt: "", prices: prices)
        }
        
        // Create CardMarket prices and object
        let cardMarketPrices = CardMarketPrices(
            averageSellPrice: currentPrice,
            lowPrice: currentPrice != nil ? currentPrice! * 0.9 : nil,
            trendPrice: currentPrice
        )
        
        let cardmarket = CardMarket(
            url: "https://www.cardmarket.com/en/Pokemon/Cards/\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)",
            updatedAt: "",
            prices: cardMarketPrices
        )
        
        // Create Set if setID and setName are available
        var set: Set? = nil
        if let setID = setID, let setName = setName {
            // Create a minimal Set with required properties
            let setImages = SetImages(symbol: "", logo: "")
            set = Set(
                id: setID,
                name: setName,
                series: "",
                printedTotal: 0,
                total: 0,
                legalities: nil,
                releaseDate: "",
                images: setImages
            )
        }
        
        // Create subtypes array with rarity if available
        var subtypes: [String]? = nil
        if let rarity = self.rarity {
            subtypes = [rarity]
        }
        
        return Card(
            id: id,
            name: name,
            supertype: supertype,
            subtypes: subtypes,
            hp: nil,
            types: types,
            evolvesFrom: nil,
            evolvesTo: nil,
            rules: nil,
            images: cardImages,
            tcgplayer: tcgPlayer,
            cardmarket: cardmarket,
            number: number,
            set: set,
            rarity: rarity
        )
    }
} 