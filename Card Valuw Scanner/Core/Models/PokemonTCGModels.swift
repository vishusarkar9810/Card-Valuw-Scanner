import Foundation

// Card Models
struct CardResponse: Codable {
    let data: Card
}

struct CardsResponse: Codable {
    let data: [Card]
    let page: Int
    let pageSize: Int
    let count: Int
    let totalCount: Int
}

struct Card: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let supertype: String
    let subtypes: [String]?
    let hp: String?
    let types: [String]?
    let evolvesFrom: String?
    let evolvesTo: [String]?
    let rules: [String]?
    let images: CardImages
    let tcgplayer: TcgPlayer?
    let cardmarket: CardMarket?
    // Add other properties as needed
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.id == rhs.id
    }
}

struct CardImages: Codable, Hashable {
    let small: String
    let large: String
}

struct TcgPlayer: Codable, Hashable {
    let url: String
    let updatedAt: String
    let prices: Prices?
}

struct Prices: Codable, Hashable {
    let normal: PriceDetails?
    let holofoil: PriceDetails?
    let reverseHolofoil: PriceDetails?
    // Add other price types as needed
}

struct PriceDetails: Codable, Hashable {
    let low: Double?
    let mid: Double?
    let high: Double?
    let market: Double?
    let directLow: Double?
}

struct CardMarket: Codable, Hashable {
    let url: String
    let updatedAt: String
    let prices: CardMarketPrices?
}

struct CardMarketPrices: Codable, Hashable {
    let averageSellPrice: Double?
    let lowPrice: Double?
    let trendPrice: Double?
    // Add other price properties as needed
}

// Set Models
struct SetsResponse: Codable {
    let data: [Set]
}

struct Set: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let series: String
    let printedTotal: Int
    let total: Int
    let legalities: Legalities?
    let releaseDate: String
    let images: SetImages
    
    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Set, rhs: Set) -> Bool {
        return lhs.id == rhs.id
    }
}

struct SetImages: Codable, Hashable {
    let symbol: String
    let logo: String
}

struct Legalities: Codable, Hashable {
    let unlimited: String?
    let standard: String?
    let expanded: String?
} 