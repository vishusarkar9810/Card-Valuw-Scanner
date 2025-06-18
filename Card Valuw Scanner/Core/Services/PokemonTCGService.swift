import Foundation
import Alamofire

class PokemonTCGService {
    private let baseURL = "https://api.pokemontcg.io/v2"
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    private var headers: HTTPHeaders {
        return ["X-Api-Key": apiKey]
    }
    
    // Get card by ID
    func getCard(id: String, completion: @escaping (Result<CardResponse, Error>) -> Void) {
        let url = "\(baseURL)/cards/\(id)"
        
        AF.request(url, headers: headers)
          .validate()
          .responseDecodable(of: CardResponse.self) { response in
              switch response.result {
              case .success(let cardResponse):
                  completion(.success(cardResponse))
              case .failure(let error):
                  completion(.failure(error))
              }
          }
    }
    
    // Search cards with query parameters
    func searchCards(query: [String: Any], completion: @escaping (Result<CardsResponse, Error>) -> Void) {
        let url = "\(baseURL)/cards"
        
        AF.request(url, parameters: query, headers: headers)
          .validate()
          .responseDecodable(of: CardsResponse.self) { response in
              switch response.result {
              case .success(let cardsResponse):
                  completion(.success(cardsResponse))
              case .failure(let error):
                  completion(.failure(error))
              }
          }
    }
    
    // Get all sets
    func getSets(completion: @escaping (Result<SetsResponse, Error>) -> Void) {
        let url = "\(baseURL)/sets"
        
        AF.request(url, headers: headers)
          .validate()
          .responseDecodable(of: SetsResponse.self) { response in
              switch response.result {
              case .success(let setsResponse):
                  completion(.success(setsResponse))
              case .failure(let error):
                  completion(.failure(error))
              }
          }
    }
    
    // MARK: - Price History
    
    // Get price history for a card
    // Note: Since the Pokemon TCG API doesn't provide historical price data directly,
    // we'll simulate it using the current price data with some variations
    func getPriceHistory(for cardId: String, completion: @escaping (Result<[(date: Date, price: Double)], Error>) -> Void) {
        getCard(id: cardId) { result in
            switch result {
            case .success(let cardResponse):
                let card = cardResponse.data
                
                // Get base price from card if available
                var basePrice: Double = 10.0
                if let market = card.tcgplayer?.prices?.normal?.market ?? 
                               card.tcgplayer?.prices?.holofoil?.market ??
                               card.tcgplayer?.prices?.reverseHolofoil?.market {
                    basePrice = market
                } else if let avg = card.cardmarket?.prices?.averageSellPrice {
                    basePrice = avg
                }
                
                // Generate more realistic price history
                let priceHistory = self.generateRealisticPriceHistory(basePrice: basePrice)
                completion(.success(priceHistory))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func generateRealisticPriceHistory(basePrice: Double) -> [(date: Date, price: Double)] {
        var priceHistory: [(date: Date, price: Double)] = []
        let calendar = Calendar.current
        let today = Date()
        
        // Create a more realistic price trend with some patterns
        // Start with a price that's 70-90% of current price 6 months ago
        var currentPrice = basePrice * Double.random(in: 0.7...0.9)
        
        // Generate weekly price points for the last 6 months
        for i in (0..<26).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i * 7, to: today) {
                // Add some small random variations (±3%)
                let randomFactor = Double.random(in: 0.97...1.03)
                
                // Add a small trend factor (0.5-1.5% increase per week on average)
                let trendFactor = Double.random(in: 1.005...1.015)
                
                // Apply both factors
                currentPrice = currentPrice * randomFactor * trendFactor
                
                // Add seasonal effects (e.g., higher prices during holidays)
                let month = calendar.component(.month, from: date)
                if month == 12 || month == 11 { // Holiday season
                    currentPrice *= 1.05 // 5% holiday premium
                }
                
                priceHistory.append((date: date, price: currentPrice))
            }
        }
        
        // Ensure the last price is close to the current price
        if let lastDate = priceHistory.last?.date {
            priceHistory.append((date: today, price: basePrice))
        }
        
        return priceHistory
    }
    
    // MARK: - Async/Await versions
    
    // Get card by ID with async/await
    func getCard(id: String) async throws -> CardResponse {
        return try await withCheckedThrowingContinuation { continuation in
            getCard(id: id) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // Search cards with async/await
    func searchCards(query: [String: Any]) async throws -> CardsResponse {
        return try await withCheckedThrowingContinuation { continuation in
            searchCards(query: query) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // Get all sets with async/await
    func getSets() async throws -> SetsResponse {
        return try await withCheckedThrowingContinuation { continuation in
            getSets() { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // Get price history with async/await
    func getPriceHistory(for cardId: String) async throws -> [(date: Date, price: Double)] {
        return try await withCheckedThrowingContinuation { continuation in
            getPriceHistory(for: cardId) { result in
                continuation.resume(with: result)
            }
        }
    }
} 