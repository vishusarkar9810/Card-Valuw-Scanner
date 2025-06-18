import SwiftUI

struct ScannerView: View {
    // MARK: - Properties
    
    let model: ScannerViewModel
    
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showLiveScanner = false
    @State private var showPhotoLibrary = false
    @State private var showResults = false
    @State private var showDebugInfo = false // Toggle for debug info
    @State private var showPotentialMatches = false // Toggle for showing potential matches
    @State private var showAddedFeedback = false // Added for visual feedback
    @State private var showScanningTips = false // Toggle for showing scanning tips
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                if model.isProcessing {
                    loadingView
                } else if let card = model.scanResult {
                    cardResultView(card)
                } else if let errorMessage = model.errorMessage {
                    errorView(errorMessage)
                } else {
                    initialView
                }
                
                // Debug info section (only visible in DEBUG mode)
                #if DEBUG
                if showDebugInfo, let debugInfo = model.debugInfo {
                    VStack(alignment: .leading) {
                        Text("Debug Info:")
                            .font(.headline)
                        
                        Text(debugInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.1))
                }
                #endif
            }
            .navigationTitle("Card Scanner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        model.reset()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(model.isProcessing || (model.scanResult == nil && model.errorMessage == nil))
                }
                
                // Debug toggle in DEBUG mode
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        showDebugInfo.toggle()
                    }) {
                        Image(systemName: showDebugInfo ? "ladybug.fill" : "ladybug")
                    }
                }
                #endif
                
                // Show scanning tips button
                ToolbarItem(placement: .bottomBar) {
                    Button(action: {
                        showScanningTips.toggle()
                    }) {
                        Label("Scanning Tips", systemImage: "questionmark.circle")
                    }
                }
                
                // Show potential matches button when available
                if !model.potentialMatches.isEmpty && model.potentialMatches.count > 1 {
                    ToolbarItem(placement: .bottomBar) {
                        Button(action: {
                            showPotentialMatches.toggle()
                        }) {
                            Label("Show \(model.potentialMatches.count) Potential Matches", systemImage: "list.bullet")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                // Use the camera view with camera source type
                CardScannerCameraView(capturedImage: $capturedImage, isPresented: $showCamera)
            }
            .sheet(isPresented: $showLiveScanner) {
                // Use our new live card scanner view
                LiveCardScannerView(capturedImage: $capturedImage, isPresented: $showLiveScanner)
            }
            .sheet(isPresented: $showPhotoLibrary) {
                // Use UIImagePickerController directly for photo library
                CardImagePicker(selectedImage: $capturedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showPotentialMatches) {
                potentialMatchesView
            }
            .sheet(isPresented: $showScanningTips) {
                scanningTipsView
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        await model.processImage(image)
                        showResults = true
                    }
                }
            }
            // Add an overlay for feedback when card is added
            .overlay(
                Group {
                    if showAddedFeedback {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                Text("Added to Collection!")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Color.green.opacity(0.9))
                            .cornerRadius(10)
                            .padding(.bottom, 50)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            // Hide the feedback after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showAddedFeedback = false
                                }
                            }
                        }
                    }
                }
            )
        }
    }
    
    // MARK: - Subviews
    
    private var initialView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Scan a Pokemon Card")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Position the card within the frame and take a photo")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 12) {
                // New Live Scanning Button
                Button(action: {
                    showLiveScanner = true
                }) {
                    HStack {
                        Image(systemName: "viewfinder.circle")
                        Text("Live Card Scanning")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    showCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take Photo")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Fixed button for photo library
                Button(action: {
                    showPhotoLibrary = true
                }) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Choose from Library")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
                    .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            
            ProgressView()
                .scaleEffect(2)
                .padding()
            
            Text("Scanning Card...")
                .font(.headline)
                .padding()
            
            // Display the current scan stage for better user feedback
            Text(scanStageDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let image = model.lastScannedImage {
                VStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                        )
                    
                    // Show progress indicators for different recognition stages
                    HStack(spacing: 20) {
                        ScanStageIndicator(
                            title: "Detect",
                            isActive: true,
                            isComplete: true
                        )
                        
                        ScanStageIndicator(
                            title: "Recognize",
                            isActive: true,
                            isComplete: model.scanStage != .initial
                        )
                        
                        ScanStageIndicator(
                            title: "Match",
                            isActive: model.scanStage != .initial,
                            isComplete: model.scanResult != nil
                        )
                    }
                    .padding(.top, 8)
                }
            }
            
            Spacer()
        }
    }
    
    // A visual indicator for scan stages
    private struct ScanStageIndicator: View {
        let title: String
        let isActive: Bool
        let isComplete: Bool
        
        var body: some View {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 30, height: 30)
                    
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else if isActive {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(isActive ? .primary : .secondary)
            }
        }
        
        private var backgroundColor: Color {
            if isComplete {
                return .green
            } else if isActive {
                return .blue
            } else {
                return .gray.opacity(0.3)
            }
        }
    }
    
    private func cardResultView(_ card: Card) -> some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                // Card image
                if let imageUrl = URL(string: card.images.large) {
                    AsyncImage(url: imageUrl) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                        } else if phase.error != nil {
                                    Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                                .frame(height: 300)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(ProgressView())
                        }
                    }
                    .frame(height: 300)
                }
                
                // Card info
                VStack(alignment: .leading, spacing: 15) {
                    Text(card.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Card details
                    cardDetailsView(card)
                    
                    // Pricing information
                    pricingView(card)
                    
                    // Action buttons
                    HStack {
                        // Add to collection button
                        Button(action: {
                            if model.addToCollection() {
                                withAnimation {
                                    showAddedFeedback = true
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: model.addedToCollection ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(model.addedToCollection ? "In Collection" : "Add to Collection")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(model.addedToCollection ? Color.green : Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(model.addedToCollection)
                        
                        // Scan again button
                        Button(action: {
                            model.reset()
                            showCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Scan Another")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    private func cardDetailsView(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card type and HP
            HStack {
                        if let types = card.types, !types.isEmpty {
                    HStack {
                            ForEach(types, id: \.self) { type in
                                Text(type)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(typeColor(for: type))
                                .foregroundColor(.white)
                                    .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                    
                    if let hp = card.hp {
                    Text("\(hp) HP")
                            .font(.headline)
                        .foregroundColor(.red)
                }
                    }
                    
                    Divider()
                    
            // Card subtypes and rarity
            if let subtypes = card.subtypes, !subtypes.isEmpty {
                Text(subtypes.joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Card number and set
            if let number = card.number, let set = card.set {
                Text("Card #\(number) • \(set.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Evolution info
            if let evolvesFrom = card.evolvesFrom {
                Text("Evolves from: \(evolvesFrom)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func pricingView(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 10) {
                        Text("Market Prices")
                .font(.headline)
                        
                        if let tcgplayer = card.tcgplayer, let prices = tcgplayer.prices {
                // TCG Player prices
                VStack(alignment: .leading, spacing: 5) {
                            if let normal = prices.normal, let market = normal.market {
                                priceRow(label: "Normal", value: market)
                            }
                            
                            if let holofoil = prices.holofoil, let market = holofoil.market {
                                priceRow(label: "Holofoil", value: market)
                            }
                            
                            if let reverseHolofoil = prices.reverseHolofoil, let market = reverseHolofoil.market {
                                priceRow(label: "Reverse Holofoil", value: market)
                    }
                            }
                            
                // Last updated
                Text("Last updated: \(formattedDate(tcgplayer.updatedAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
            } else if let cardmarket = card.cardmarket, let prices = cardmarket.prices {
                // Cardmarket prices
                VStack(alignment: .leading, spacing: 5) {
                    if let trendPrice = prices.trendPrice {
                        priceRow(label: "Trend Price", value: trendPrice, currency: "€")
                        }
                    
                    if let avgPrice = prices.averageSellPrice {
                        priceRow(label: "Average Sell Price", value: avgPrice, currency: "€")
                    }
                    
                    if let lowPrice = prices.lowPrice {
                        priceRow(label: "Low Price", value: lowPrice, currency: "€")
                        }
                }
                
                // Last updated
                Text("Last updated: \(formattedDate(cardmarket.updatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No pricing information available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func priceRow(label: String, value: Double, currency: String = "$") -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(currency)\(String(format: "%.2f", value))")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
    
    private func errorView(_ errorMessage: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Scanning Error")
                .font(.title)
                .fontWeight(.bold)
            
            Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !model.potentialMatches.isEmpty {
                Text("We found \(model.potentialMatches.count) potential matches.")
                    .font(.headline)
                    .padding(.top)
                
                Button(action: {
                    showPotentialMatches = true
                }) {
                    Text("View Potential Matches")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            
            if model.scanStage != .failed {
                Button(action: {
                    Task {
                        await model.tryScanAgain()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Different Approach")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                .padding(.top)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    model.reset()
                    showLiveScanner = true
                }) {
                    HStack {
                        Image(systemName: "viewfinder.circle")
                        Text("Try Live Card Scanner")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    model.reset()
                    showCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Take New Photo")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    model.reset()
                }) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("Cancel")
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private var potentialMatchesView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let image = model.lastScannedImage {
                    // Header with scanned image
                    VStack {
                        Text("Scanned Image")
                            .font(.headline)
                            .padding(.top)
                        
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 150)
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    .background(Color.gray.opacity(0.1))
                }
                
                // Instructions
                Text("Select the correct card from the matches below")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                
                // Card matches
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                        ForEach(model.potentialMatches) { card in
                            Button(action: {
                                model.selectMatch(card)
                                showPotentialMatches = false
                            }) {
                                VStack {
                                    AsyncImage(url: URL(string: card.images.small)) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(height: 180)
                                                .cornerRadius(8)
                                        } else if phase.error != nil {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 180)
                                                .cornerRadius(8)
                                                .overlay(
                                                    Image(systemName: "exclamationmark.triangle")
                                                        .foregroundColor(.gray)
                                                )
                                        } else {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 180)
                                                .cornerRadius(8)
                                                .overlay(
                                                    ProgressView()
                                                )
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(card.name)
                                            .font(.headline)
                                            .lineLimit(1)
                                        
                                        if let number = card.number, let set = card.set {
                                            Text("#\(number) • \(set.name)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        // Show price if available
                                        if let tcgplayer = card.tcgplayer,
                                           let prices = tcgplayer.prices,
                                           let normal = prices.normal,
                                           let market = normal.market {
                                            Text("$\(String(format: "%.2f", market))")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.bottom, 8)
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: card.id == model.scanResult?.id ? 3 : 0)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Potential Matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showPotentialMatches = false
                    }
                }
            }
        }
    }
    
    private var scanningTipsView: some View {
        NavigationStack {
            List {
                Section(header: Text("Scanning Modes")) {
                    tipRow(icon: "viewfinder.circle", title: "Live Card Scanning", description: "Automatically detects card edges and captures when stable. Best for quick scanning.")
                    tipRow(icon: "camera", title: "Manual Photo", description: "Take a photo manually. Good for difficult lighting conditions.")
                    tipRow(icon: "photo", title: "Photo Library", description: "Select existing photos of cards from your library.")
                }
                
                Section(header: Text("General Tips")) {
                    tipRow(icon: "light.max", title: "Good Lighting", description: "Ensure the card is well-lit without glare. Natural light works best.")
                    tipRow(icon: "camera.viewfinder", title: "Proper Framing", description: "Position the card within the green frame so all text is visible.")
                    tipRow(icon: "hand.raised.fill", title: "Hold Steady", description: "Keep your hand steady to avoid blurry images.")
                    tipRow(icon: "sparkles", title: "Clean Card", description: "Make sure the card is clean and free of fingerprints or smudges.")
                }
                
                Section(header: Text("What to Focus On")) {
                    tipRow(icon: "textformat", title: "Card Name", description: "Make sure the card name is clearly visible and in focus.")
                    tipRow(icon: "number", title: "Card Number", description: "The card number (e.g. '25/102') helps with accurate identification.")
                    tipRow(icon: "square.grid.2x2", title: "Set Symbol", description: "The set symbol (usually in the bottom right) helps identify the card set.")
                    tipRow(icon: "heart.fill", title: "HP Value", description: "The HP number can help identify the card if other text isn't clear.")
                }
                
                Section(header: Text("Troubleshooting")) {
                    tipRow(icon: "bolt.fill", title: "Use Flash", description: "In low light, enable the flashlight using the lightning bolt icon.")
                    tipRow(icon: "arrow.clockwise", title: "Try Different Angles", description: "If scanning fails, try a slightly different angle to reduce glare.")
                    tipRow(icon: "photo", title: "Use Photo Library", description: "For better results, take a photo first, then crop it closely around the card.")
                    tipRow(icon: "hand.tap", title: "Manual Selection", description: "If multiple matches are found, tap the correct card from the list.")
                }
            }
            .navigationTitle("Scanning Tips")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showScanningTips = false
                    }
                }
            }
        }
    }
    
    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
    
    // MARK: - Helper Methods
    
    private func formattedDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            return dateFormatter.string(from: date)
        }
        
        return dateString
    }
    
    private func typeColor(for type: String) -> Color {
        switch type.lowercased() {
        case "colorless", "normal": return Color.gray
        case "fire": return Color.red
        case "water": return Color.blue
        case "grass": return Color.green
        case "electric", "lightning": return Color.yellow
        case "fighting": return Color.orange
        case "psychic": return Color.purple
        case "metal", "steel": return Color(UIColor.lightGray)
        case "darkness", "dark": return Color(UIColor.darkGray)
        case "dragon": return Color.indigo
        case "fairy": return Color.pink
        default: return Color.gray
        }
    }
    
    private var scanStageDescription: String {
        switch model.scanStage {
        case .initial:
            return "Analyzing card image..."
        case .enhancedText:
            return "Enhancing image for better text recognition..."
        case .nameSearch:
            return "Searching for card by name..."
        case .numberSearch:
            return "Searching for card by number..."
        case .visualSearch:
            return "Analyzing visual features..."
        case .failed:
            return "Unable to identify card."
        }
    }
} 