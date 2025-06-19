import Foundation
import SwiftUI
import SwiftData

@Model
final class CollectionEntity {
    var id: UUID
    var name: String
    var imageURL: String?
    var dateCreated: Date
    var isDefault: Bool
    var cards: [CardEntity] = []
    
    init(
        id: UUID = UUID(),
        name: String,
        imageURL: String? = nil,
        dateCreated: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.dateCreated = dateCreated
        self.isDefault = isDefault
    }
    
    var cardCount: Int {
        cards.map { $0.quantity }.reduce(0, +)
    }
    
    var totalValue: Double {
        cards.compactMap { card in
            if let price = card.currentPrice {
                return price * Double(card.quantity)
            }
            return nil
        }.reduce(0, +)
    }
} 