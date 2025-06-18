import SwiftUI
import SwiftData

struct BrowseView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: BrowseViewModel
    @State private var searchText: String = ""
    @State private var selectedSet: Set? = nil
    @State private var selectedCard: Card? = nil
    
    // MARK: - Initialization
    
    init(pokemonTCGService: PokemonTCGService, persistenceManager: PersistenceManager) {
        self._viewModel = StateObject(wrappedValue: BrowseViewModel(
            pokemonTCGService: pokemonTCGService,
            persistenceManager: persistenceManager
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else if selectedSet != nil {
                    cardsInSetView
                } else {
                    setsListView
                }
            }
            .navigationTitle("Browse")
            .searchable(text: $searchText, prompt: "Search sets or cards")
            .onChange(of: searchText) { _, newValue in
                if selectedSet != nil {
                    viewModel.searchCardsInSet(searchText: newValue)
                } else {
                    viewModel.searchSets(searchText: newValue)
                }
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card)
            }
            .toolbar {
                if selectedSet != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            selectedSet = nil
                            searchText = ""
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Sets")
                            }
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Sort by Name") {
                                viewModel.sortCardsBy(.name)
                            }
                            Button("Sort by Number") {
                                viewModel.sortCardsBy(.number)
                            }
                            Button("Sort by Rarity") {
                                viewModel.sortCardsBy(.rarity)
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
            }
            .task {
                await viewModel.loadSets()
            }
            .refreshable {
                if selectedSet != nil {
                    await viewModel.loadCardsInSet(set: selectedSet!)
                } else {
                    await viewModel.loadSets()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(2)
                .padding()
            
            Text(selectedSet != nil ? "Loading cards..." : "Loading sets...")
                .font(.headline)
                .padding()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                Task {
                    if selectedSet != nil {
                        await viewModel.loadCardsInSet(set: selectedSet!)
                    } else {
                        await viewModel.loadSets()
                    }
                }
            }) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var setsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(viewModel.filteredSets) { set in
                    Button(action: {
                        selectedSet = set
                        Task {
                            await viewModel.loadCardsInSet(set: set)
                        }
                    }) {
                        SetListItem(set: set)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
    
    private var cardsInSetView: some View {
        ScrollView {
            if let selectedSet = selectedSet {
                VStack(alignment: .leading, spacing: 16) {
                    // Set header
                    HStack {
                        if let logoUrl = URL(string: selectedSet.images.logo) {
                            AsyncImage(url: logoUrl) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 50)
                                } else {
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.2))
                                        .frame(width: 120, height: 50)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("\(viewModel.cards.count) / \(selectedSet.total) cards")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Released: \(formatDate(selectedSet.releaseDate ?? ""))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Cards grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                        ForEach(viewModel.filteredCards) { card in
                            CardGridItem(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(selectedSet?.name ?? "Cards")
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct SetListItem: View {
    let set: Set
    
    var body: some View {
        HStack {
            if let symbolUrl = URL(string: set.images.symbol) {
                AsyncImage(url: symbolUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .foregroundColor(.gray.opacity(0.2))
                            .frame(width: 30, height: 30)
                    }
                }
                .padding(.trailing, 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(set.name)
                    .font(.headline)
                
                Text("\(set.series) • \(set.printedTotal) cards")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CardEntity.self, configurations: config)
    
    let persistenceManager = PersistenceManager(modelContext: ModelContext(container))
    let pokemonTCGService = PokemonTCGService(apiKey: "your-api-key")
    
    BrowseView(
        pokemonTCGService: pokemonTCGService,
        persistenceManager: persistenceManager
    )
} 