import SwiftUI
import SwiftData

struct MainTabView: View {
    // MARK: - Properties
    
    private let pokemonTCGService: PokemonTCGService
    private let cardScannerService: CardScannerService
    
    @Environment(\.modelContext) private var modelContext
    
    private let scannerViewModel: ScannerViewModel
    private let collectionViewModel: CollectionViewModel
    @State private var persistenceManager: PersistenceManager
    
    // MARK: - Initialization
    
    init() {
        // Initialize services
        self.pokemonTCGService = PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey)
        self.cardScannerService = CardScannerService()
        
        // Create a temporary model container and context for initialization
        // This will be replaced with the proper injected modelContext in onAppear
        let tempContainer: ModelContainer
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            tempContainer = try ModelContainer(for: CardEntity.self, configurations: config)
        } catch {
            fatalError("Failed to create temporary model container: \(error)")
        }
        
        let tempPersistenceManager = PersistenceManager(modelContext: ModelContext(tempContainer))
        self.persistenceManager = tempPersistenceManager
        
        // Initialize view models
        self.scannerViewModel = ScannerViewModel(
            cardScannerService: cardScannerService,
            pokemonTCGService: pokemonTCGService,
            persistenceManager: tempPersistenceManager
        )
        
        self.collectionViewModel = CollectionViewModel(
            pokemonTCGService: pokemonTCGService,
            persistenceManager: tempPersistenceManager
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView {
            ScannerView(model: scannerViewModel)
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
            
            BrowseView(pokemonTCGService: pokemonTCGService, persistenceManager: persistenceManager)
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
            
            CollectionView(model: collectionViewModel)
                .tabItem {
                    Label("Collection", systemImage: "folder")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .onAppear {
            // Update the persistence manager with the injected model context
            persistenceManager = PersistenceManager(modelContext: modelContext)
            
            // Update view models with the new persistence manager
            scannerViewModel.updatePersistenceManager(persistenceManager)
            collectionViewModel.updatePersistenceManager(persistenceManager)
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: CardEntity.self, inMemory: true)
} 