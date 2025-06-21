import SwiftUI
import SwiftData

struct MainTabView: View {
    // MARK: - Properties
    
    private let pokemonTCGService: PokemonTCGService
    private let cardScannerService: CardScannerService
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.subscriptionService) private var subscriptionService
    @State private var selectedTab = 0
    @State private var showingScanner = false
    @State private var showingSettings = false
    @State private var showingSubscriptions = false
    
    // Create shared instances of view models
    @State private var scannerViewModel: ScannerViewModel
    @State private var collectionViewModel: CollectionViewModel
    @State private var browseViewModel: BrowseViewModel
    
    // MARK: - Initialization
    
    @MainActor
    init() {
        // Initialize services
        self.pokemonTCGService = PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey)
        self.cardScannerService = CardScannerService()
        
        // Create a temporary model container and context for initialization
        // This will be replaced with the proper injected modelContext in onAppear
        let tempContainer: ModelContainer
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            tempContainer = try ModelContainer(for: CardEntity.self, CollectionEntity.self, configurations: config)
        } catch {
            fatalError("Failed to create temporary model container: \(error)")
        }
        
        let tempPersistenceManager = PersistenceManager(modelContext: ModelContext(tempContainer))
        
        // Initialize view models with shared persistence manager
        _scannerViewModel = State(initialValue: ScannerViewModel(cardScannerService: cardScannerService, pokemonTCGService: pokemonTCGService, persistenceManager: tempPersistenceManager))
        _collectionViewModel = State(initialValue: CollectionViewModel(pokemonTCGService: pokemonTCGService, persistenceManager: tempPersistenceManager, subscriptionService: SubscriptionService()))
        _browseViewModel = State(initialValue: BrowseViewModel(pokemonTCGService: pokemonTCGService, persistenceManager: tempPersistenceManager))
    }
    
    // MARK: - Body
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(model: scannerViewModel)
                .tabItem {
                    Label("Scan", systemImage: "camera")
                }
                .tag(0)
                .onChange(of: scannerViewModel.addedToCollection) { oldValue, newValue in
                    // When a card is added to collection, ensure collection view will refresh
                    if newValue && !oldValue {
                        // Force a refresh when switching to collection tab
                        collectionViewModel.shouldRefresh = true
                    }
                }
            
            BrowseView(model: browseViewModel)
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
                .tag(1)
            
            CollectionView(model: collectionViewModel)
                .tabItem {
                    Label("Collection", systemImage: "folder")
                }
                .tag(2)
                .onChange(of: selectedTab) { oldValue, newValue in
                    if newValue == 2 {
                        // Refresh collection when switching to collection tab
                        collectionViewModel.loadCollection()
                    }
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // Update the persistence manager with the injected model context
            let persistenceManager = PersistenceManager(modelContext: modelContext)
            
            // Update view models with the new persistence manager
            scannerViewModel.updatePersistenceManager(persistenceManager)
            collectionViewModel.updatePersistenceManager(persistenceManager)
            
            // For browse view model, create a new instance with the correct persistence manager
            browseViewModel = BrowseViewModel(pokemonTCGService: pokemonTCGService, persistenceManager: persistenceManager)
            
            // Preload the data for collection view on app start
            if selectedTab == 2 {
                collectionViewModel.loadCollection()
            }
        }
    }
}

#Preview {
    @MainActor func previewFactory() -> some View {
        MainTabView()
            .modelContainer(for: [CardEntity.self, CollectionEntity.self], inMemory: true)
            .environment(SubscriptionService())
    }
    
    return previewFactory()
} 