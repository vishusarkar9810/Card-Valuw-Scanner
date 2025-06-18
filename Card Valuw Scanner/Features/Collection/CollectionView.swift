import SwiftUI
import UIKit

struct CollectionView: View {
    // MARK: - Properties
    
    let model: CollectionViewModel
    
    @State private var showingFilters = false
    @State private var selectedCard: Card? = nil
    @State private var searchText: String = ""
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                if model.isLoading {
                    loadingView
                } else if let errorMessage = model.errorMessage {
                    errorView(errorMessage)
                } else if model.cards.isEmpty {
                    emptyCollectionView
                } else {
                    collectionGridView
                }
            }
            .navigationTitle("My Collection")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        showingFilters = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Sort by Name") {
                            // Sort by name
                        }
                        Button("Sort by Value") {
                            // Sort by value
                        }
                        Button("Sort by Set") {
                            // Sort by set
                        }
                        Divider()
                        Button(model.showFavoritesOnly ? "Show All Cards" : "Show Favorites Only") {
                            model.showFavoritesOnly.toggle()
                            model.applyFilters()
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search your collection")
            .onChange(of: searchText) { _, newValue in
                model.searchText = newValue
                model.applyFilters()
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(
                    selectedTypes: model.selectedTypes,
                    selectedSets: model.selectedSets,
                    onTypeSelection: { types in
                        model.selectedTypes = types
                        model.applyFilters()
                    },
                    onSetSelection: { sets in
                        model.selectedSets = sets
                        model.applyFilters()
                    },
                    onApply: {
                        model.applyFilters()
                    },
                    onReset: {
                        model.resetFilters()
                        searchText = ""
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .navigationDestination(item: $selectedCard) { card in
                CardDetailView(card: card)
            }
            .task {
                // Just load the collection without adding sample cards
                    model.loadCollection()
            }
            .refreshable {
                model.loadCollection()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(2)
                .padding()
            
            Text("Loading collection...")
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
                model.loadCollection()
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
    
    private var emptyCollectionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Cards Yet")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Scan cards using the camera to add them to your collection")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                // Navigate to scanner tab
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let tabBarController = windowScene.windows.first?.rootViewController as? UITabBarController {
                    tabBarController.selectedIndex = 0 // Assuming Scanner is the first tab
                }
            }) {
                HStack {
                    Image(systemName: "camera")
                    Text("Scan Cards")
                }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var collectionGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(model.cards) { card in
                    CardGridItem(card: card)
                        .contextMenu {
                            Button(action: {
                                model.toggleFavorite(for: card)
                            }) {
                                Label(
                                    model.cardEntities.first(where: { $0.id == card.id })?.isFavorite == true ? "Remove from Favorites" : "Add to Favorites",
                                    systemImage: model.cardEntities.first(where: { $0.id == card.id })?.isFavorite == true ? "star.fill" : "star"
                                )
                            }
                            
                            Button(action: {
                                model.increaseCardQuantity(with: card.id)
                                model.loadCollection()
                            }) {
                                Label("Add One More", systemImage: "plus.circle")
                            }
                            
                            Button(action: {
                                model.decreaseCardQuantity(with: card.id)
                            }) {
                                Label("Remove One", systemImage: "minus.circle")
                            }
                            
                            Button(role: .destructive, action: {
                                model.removeCard(with: card.id)
                            }) {
                                Label("Remove All", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            selectedCard = card
                        }
                }
            }
            .padding()
            
            // Collection summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Collection Summary")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Cards")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(model.cardEntities.map { $0.quantity }.reduce(0, +))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Value")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("$\(String(format: "%.2f", model.totalCollectionValue))")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct CardGridItem: View {
    let card: Card
    
    var body: some View {
        VStack {
            if let imageURL = URL(string: card.images.small) {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    } else if phase.error != nil {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.2))
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            )
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.2))
                            .overlay(
                                ProgressView()
                            )
                            .cornerRadius(8)
                    }
                }
            }
            
            Text(card.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            if let price = card.tcgplayer?.prices?.normal?.market ?? card.tcgplayer?.prices?.holofoil?.market {
                Text("$\(String(format: "%.2f", price))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct FilterView: View {
    // State for tracking selected filters
    @State private var localSelectedTypes: [String]
    @State private var localSelectedSets: [String]
    
    // Callbacks
    let onTypeSelection: ([String]) -> Void
    let onSetSelection: ([String]) -> Void
    let onApply: () -> Void
    let onReset: () -> Void
    
    // Sample types and sets for demo
    let types = ["Colorless", "Darkness", "Dragon", "Fairy", "Fighting", "Fire", "Grass", "Lightning", "Metal", "Psychic", "Water"]
    let sets = [
        (id: "swsh1", name: "Sword & Shield"),
        (id: "swsh2", name: "Rebel Clash"),
        (id: "swsh3", name: "Darkness Ablaze"),
        (id: "swsh4", name: "Vivid Voltage"),
        (id: "swsh5", name: "Battle Styles")
    ]
    
    // Initialize with current selections
    init(selectedTypes: [String], selectedSets: [String], onTypeSelection: @escaping ([String]) -> Void, onSetSelection: @escaping ([String]) -> Void, onApply: @escaping () -> Void, onReset: @escaping () -> Void) {
        self._localSelectedTypes = State(initialValue: selectedTypes)
        self._localSelectedSets = State(initialValue: selectedSets)
        self.onTypeSelection = onTypeSelection
        self.onSetSelection = onSetSelection
        self.onApply = onApply
        self.onReset = onReset
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Types")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(types, id: \.self) { type in
                                FilterChip(
                                    title: type,
                                    isSelected: localSelectedTypes.contains(type),
                                    onToggle: {
                                        if localSelectedTypes.contains(type) {
                                            localSelectedTypes.removeAll { $0 == type }
                                        } else {
                                            localSelectedTypes.append(type)
                                        }
                                        onTypeSelection(localSelectedTypes)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Sets")) {
                    ForEach(sets, id: \.id) { set in
                        Button(action: {
                            if localSelectedSets.contains(set.id) {
                                localSelectedSets.removeAll { $0 == set.id }
                            } else {
                                localSelectedSets.append(set.id)
                            }
                            onSetSelection(localSelectedSets)
                        }) {
                            HStack {
                                Text(set.name)
                                Spacer()
                                if localSelectedSets.contains(set.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        localSelectedTypes = []
                        localSelectedSets = []
                        onTypeSelection([])
                        onSetSelection([])
                        onReset()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
} 