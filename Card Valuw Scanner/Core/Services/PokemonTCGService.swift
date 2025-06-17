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
} 