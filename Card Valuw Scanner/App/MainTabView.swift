import SwiftUI

struct MainTabView: View {
    // MARK: - Properties
    
    private let pokemonTCGService: PokemonTCGService
    private let cardScannerService: CardScannerService
    
    private let scannerViewModel: ScannerViewModel
    private let collectionViewModel: CollectionViewModel
    
    // MARK: - Initialization
    
    init() {
        // Initialize services
        self.pokemonTCGService = PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey)
        self.cardScannerService = CardScannerService()
        
        // Initialize view models
        self.scannerViewModel = ScannerViewModel(
            cardScannerService: cardScannerService, 
            pokemonTCGService: pokemonTCGService
        )
        
        self.collectionViewModel = CollectionViewModel(
            pokemonTCGService: pokemonTCGService
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            ScannerView(model: scannerViewModel)
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
            
            CollectionView(model: collectionViewModel)
                .tabItem {
                    Label("Collection", systemImage: "rectangle.stack")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
} 