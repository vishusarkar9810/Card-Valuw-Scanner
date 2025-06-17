import Foundation

enum Configuration {
    static let pokemonTcgApiKey: String = {
        guard let apiKey = Bundle.main.infoDictionary?["POKEMON_TCG_API_KEY"] as? String else {
            fatalError("API Key not found in Info.plist")
        }
        return apiKey
    }()
} 