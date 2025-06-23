import SwiftUI
import UIKit
import SwiftData

struct CollectionView: View {
    // MARK: - Properties
    
    @State private var model: CollectionViewModel
    
    @State private var showingFilters = false
    @State private var selectedCard: Card? = nil
    @State private var searchText: String = ""
    @State private var showingCollectionsList = true
    @State private var collectionToRename: CollectionEntity? = nil
    @State private var newCollectionName: String = ""
    @State private var showingAddCardOptions = false
    
    // MARK: - State properties
    @State private var showingSortOptions = false
    @State private var showingFilterOptions = false
    
    init(model: CollectionViewModel) {
        self._model = State(initialValue: model)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    loadingView
                } else if let errorMessage = model.errorMessage {
                    errorView(errorMessage)
                } else if model.collections.isEmpty {
                    emptyStateView
                } else if showingCollectionsList {
                    collectionsGridView
                } else if model.cardEntities.isEmpty && model.selectedCollection != nil {
                    emptyCollectionView
                } else {
                    collectionDetailView
                }
            }
            .navigationTitle(showingCollectionsList ? "Collections" : (model.selectedCollection?.name ?? "Collection"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !showingCollectionsList {
                        Button(action: {
                            showingCollectionsList = true
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Collections")
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if showingCollectionsList {
                        Button(action: {
                            model.showingCreateCollection = true
                        }) {
                            Image(systemName: "plus")
                        }
                    } else {
                        Menu {
                            Button(action: {
                                showingAddCardOptions = true
                            }) {
                                Label("Add Card", systemImage: "plus.rectangle.on.rectangle")
                            }
                            
                            Button(action: {
                                showingFilterOptions.toggle()
                            }) {
                                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                            }
                            
                            Button(action: {
                                showingSortOptions.toggle()
                            }) {
                                Label("Sort", systemImage: "arrow.up.arrow.down")
                            }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
            .sheet(isPresented: $model.showingCreateCollection) {
                createCollectionView
            }
            .sheet(item: $collectionToRename) { collection in
                renameCollectionView(collection)
            }
            .sheet(isPresented: $showingFilterOptions) {
                FilterView(model: model, showingFilters: $showingFilterOptions)
            }
            .actionSheet(isPresented: $showingSortOptions) {
                ActionSheet(
                    title: Text("Sort Cards"),
                    buttons: CollectionViewModel.SortOrder.allCases.map { order in
                        .default(Text(order.rawValue)) {
                            model.setSortOrder(order)
                        }
                    } + [.cancel()]
                )
            }
            .actionSheet(isPresented: $showingAddCardOptions) {
                ActionSheet(
                    title: Text("Add Card"),
                    message: Text("Choose how to add a card to your collection"),
                    buttons: [
                        .default(Text("Scan Card")) {
                            // Navigate to scanner tab
                            NotificationCenter.default.post(name: Notification.Name("SwitchToScannerTab"), object: nil)
                        },
                        .default(Text("Browse Catalog")) {
                            // Navigate to browse tab
                            NotificationCenter.default.post(name: Notification.Name("SwitchToBrowseTab"), object: nil)
                        },
                        .cancel()
                    ]
                )
            }
            .onAppear {
                if model.shouldRefresh {
                    model.loadCollection()
                } else if model.selectedCollection != nil {
                    // Ensure the collection value is recalculated even if we're not refreshing the whole collection
                    model.calculateTotalCollectionValue()
                }
                // Update any missing prices
                model.updateMissingPrices()
            }
        }
        .onChange(of: searchText) {
            model.searchText = searchText
            model.applyFilters()
        }
    }
    
    // MARK: - Collections Grid View
    
    private var collectionsGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(model.collections) { collection in
                    collectionGridItem(for: collection)
                }
                
                // Create New Collection button
                Button(action: {
                    model.showingCreateCollection = true
                }) {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .aspectRatio(1, contentMode: .fit)
                            
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundColor(.blue)
                        }
                        
                        Text("Create new")
                            .font(.headline)
                        
                        Text("0 cards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 200)
            }
            .padding()
        }
    }
    
    private func collectionGridItem(for collection: CollectionEntity) -> some View {
        Button(action: {
            model.selectCollection(collection)
            showingCollectionsList = false
        }) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(1, contentMode: .fit)
                    
                    if let imageURL = collection.imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                // Default image or first card in collection
                                if let firstCard = collection.cards.first {
                                    AsyncImage(url: URL(string: firstCard.imageSmallURL)) { cardPhase in
                                        if let cardImage = cardPhase.image {
                                            cardImage
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        } else {
                                            defaultCollectionImage(for: collection)
                                        }
                                    }
                                } else {
                                    defaultCollectionImage(for: collection)
                                }
                            }
                        }
                    } else if let firstCard = collection.cards.first {
                        AsyncImage(url: URL(string: firstCard.imageSmallURL)) { cardPhase in
                            if let cardImage = cardPhase.image {
                                cardImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                defaultCollectionImage(for: collection)
                            }
                        }
                    } else {
                        defaultCollectionImage(for: collection)
                    }
                }
                
                Text(collection.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(collection.cardCount) cards")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 200)
        .contextMenu {
            if !collection.isDefault {
                Button(role: .destructive, action: {
                    model.deleteCollection(collection)
                }) {
                    Label("Delete Collection", systemImage: "trash")
                }
            }
            
            Button(action: {
                collectionToRename = collection
                newCollectionName = collection.name
            }) {
                Label("Rename", systemImage: "pencil")
            }
        }
    }
    
    private func defaultCollectionImage(for collection: CollectionEntity) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
            
            Image(systemName: collection.isDefault ? "star.square.fill" : "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(collection.isDefault ? .yellow : .blue)
        }
    }
    
    // MARK: - Collection Detail View
    
    private var collectionDetailView: some View {
        VStack(spacing: 0) {
            // Search bar
            if !showingCollectionsList {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search cards", text: $searchText)
                        .onChange(of: searchText) { oldValue, newValue in
                            model.searchText = newValue
                            model.applyFilters()
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            model.searchText = ""
                            model.applyFilters()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            // Pricing header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Pricing")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Capsule()
                        .fill(Color.red)
                        .frame(width: 60, height: 24)
                        .overlay(
                            Text("Live")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
                .padding(.horizontal)
                
                // Valuation card
                collectionValuationCard
            }
            .padding(.top)
            
            // Cards grid
            cardsGrid
        }
    }
    
    private var collectionValuationCard: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Valuation")
                    .font(.headline)
                
                Spacer()
                
                Text("~$\(String(format: "%.2f", isFiltered ? model.displayedCollectionValue : model.totalCollectionValue))")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text(isFiltered ? "Value of filtered cards" : "Average price based on data from popular marketplaces")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Computed property to check if any filters are applied
    private var isFiltered: Bool {
        !model.searchText.isEmpty || 
        model.selectedTypeFilter != nil || 
        !model.selectedTypes.isEmpty || 
        model.selectedSetFilter != nil || 
        !model.selectedSets.isEmpty || 
        model.selectedRarityFilter != nil ||
        model.showFavoritesOnly
    }
    
    private var cardsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(model.cardEntities) { cardEntity in
                    cardCell(for: cardEntity)
                }
            }
            .padding()
        }
    }
    
    private func cardCell(for cardEntity: CardEntity) -> some View {
        let card = cardEntity.toCard()
        return Button(action: {
            selectedCard = card
        }) {
            VStack {
                // Card image
                if let url = URL(string: cardEntity.imageSmallURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(8)
                        } else if phase.error != nil {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .cornerRadius(8)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                )
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .cornerRadius(8)
                                .overlay(
                                    ProgressView()
                                )
                        }
                    }
                }
                
                // Card info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardEntity.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let setName = cardEntity.setName {
                        Text(setName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // Price & quantity
                    HStack {
                        if let price = cardEntity.currentPrice {
                            Text("$\(String(format: "%.2f", price))")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        if cardEntity.quantity > 1 {
                            Text("×\(cardEntity.quantity)")
                                .font(.caption)
                                .padding(4)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                if let entity = model.persistenceManager.fetchCard(withID: cardEntity.id) {
                    model.persistenceManager.toggleFavorite(entity)
                    model.loadCollection()
                }
            }) {
                Label(
                    cardEntity.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: cardEntity.isFavorite ? "heart.fill" : "heart"
                )
            }
            
            Button(action: {
                model.removeCard(with: cardEntity.id)
            }) {
                Label("Remove from Collection", systemImage: "trash")
            }
            
            Menu("Move to...") {
                ForEach(model.collections) { collection in
                    if collection.id != model.selectedCollection?.id {
                        Button(action: {
                            model.moveCard(cardEntity, to: collection)
                        }) {
                            Text(collection.name)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedCard) { card in
            CardDetailViewWrapper(card: card, model: model)
        }
    }
    
    // MARK: - Create Collection View
    
    private var createCollectionView: some View {
        NavigationStack {
            Form {
                Section(header: Text("Collection Details")) {
                    TextField("Collection Name", text: $model.newCollectionName)
                }
            }
            .navigationTitle("New Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.showingCreateCollection = false
                        model.newCollectionName = ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        model.createCollection()
                        model.showingCreateCollection = false
                    }
                    .disabled(model.newCollectionName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Rename Collection View
    
    private func renameCollectionView(_ collection: CollectionEntity) -> some View {
        NavigationStack {
            Form {
                Section(header: Text("Collection Details")) {
                    TextField("Collection Name", text: $newCollectionName)
                }
            }
            .navigationTitle("Rename Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        collectionToRename = nil
                        newCollectionName = ""
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            collection.name = newCollectionName
                            model.persistenceManager.updateCollection(collection)
                            model.loadCollections()
                        }
                        collectionToRename = nil
                        newCollectionName = ""
                    }
                    .disabled(newCollectionName.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .padding()
            Text("Loading your collection...")
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
                .padding()
            
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Try Again") {
                model.loadCollection()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("Create Your First Collection")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Start building your Pokemon card collection")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                model.showingCreateCollection = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Create Collection")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }
    
    private var emptyCollectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.on.rectangle.slash")
                .font(.system(size: 70))
                .foregroundColor(.gray)
            
            Text("Collection is empty")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Add cards by scanning or browsing the Pokemon TCG catalog")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                
            Button(action: {
                showingAddCardOptions = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add first card")
                }
                .font(.headline)
                .foregroundColor(.primary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(20)
            }
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - Filter View
struct FilterView: View {
    var model: CollectionViewModel
    @Binding var showingFilters: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Card Types")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(PokemonType.allCases, id: \.self) { type in
                                FilterChip(
                                    title: type.rawValue,
                                    isSelected: model.selectedTypes.contains(type.rawValue),
                                    action: {
                                        if model.selectedTypes.contains(type.rawValue) {
                                            model.selectedTypes.removeAll { $0 == type.rawValue }
                                        } else {
                                            model.selectedTypes.append(type.rawValue)
                                        }
                                        model.applyFilters()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Sets")) {
                    setsSection
                }
                
                Section {
                    Toggle("Show Favorites Only", isOn: Binding(
                        get: { model.showFavoritesOnly },
                        set: { model.showFavoritesOnly = $0; model.applyFilters() }
                    ))
                }
                
                Section {
                    Button("Clear All Filters") {
                        model.resetFilters()
                    }
                }
            }
            .navigationTitle("Filter Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingFilters = false
                    }
                }
            }
        }
    }
    
    private var setsSection: some View {
        let setIDs = model.cardEntities.compactMap { $0.setID }
        
        // Create a unique array of set IDs
        var uniqueSetIDs: [String] = []
        for id in setIDs {
            if !uniqueSetIDs.contains(id) {
                uniqueSetIDs.append(id)
            }
        }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(uniqueSetIDs, id: \.self) { set in
                    FilterChip(
                        title: set,
                        isSelected: model.selectedSets.contains(set),
                        action: {
                            if model.selectedSets.contains(set) {
                                model.selectedSets.removeAll { $0 == set }
                            } else {
                                model.selectedSets.append(set)
                            }
                            model.applyFilters()
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
}

// Wrapper view to simplify the CardDetailView initialization
struct CardDetailViewWrapper: View {
    let card: Card
    let model: CollectionViewModel
    
    var body: some View {
        let detailViewModel = CardDetailViewModel(card: card, pokemonTCGService: model.pokemonTCGService, persistenceManager: model.persistenceManager, collection: model.selectedCollection)
        CardDetailView(model: detailViewModel)
    }
}

// MARK: - Filter Chip View

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let persistenceManager = PersistenceManager.preview
    let pokemonTCGService = PokemonTCGService(apiKey: Configuration.pokemonTcgApiKey)
    let viewModel = CollectionViewModel(pokemonTCGService: pokemonTCGService, persistenceManager: persistenceManager, subscriptionService: SubscriptionService())
    CollectionView(model: viewModel)
}

enum PokemonType: String, CaseIterable {
    case colorless = "Colorless"
    case darkness = "Darkness"
    case dragon = "Dragon"
    case fairy = "Fairy"
    case fighting = "Fighting"
    case fire = "Fire"
    case grass = "Grass"
    case lightning = "Lightning"
    case metal = "Metal"
    case psychic = "Psychic"
    case water = "Water"
} 