import SwiftUI

struct ScannerView: View {
    // MARK: - Properties
    
    let model: ScannerViewModel
    
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showResults = false
    @State private var showDebugInfo = false // Toggle for debug info
    @State private var showPotentialMatches = false // Toggle for showing potential matches
    
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
                CardScannerCameraView(capturedImage: $capturedImage, isPresented: $showCamera)
            }
            .sheet(isPresented: $showPotentialMatches) {
                potentialMatchesView
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage {
                    Task {
                        await model.processImage(image)
                        showResults = true
                    }
                }
            }
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
                
                // Alternative option for simulators or testing
                Button(action: {
                    showCamera = true
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
            
            Text("Analyzing card...")
                .font(.headline)
                .padding()
            
            Text("This may take a moment")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Scan Failed")
                .font(.title)
                .fontWeight(.bold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let capturedImage = capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 2)
                    )
            }
            
            // Show potential matches if available
            if !model.potentialMatches.isEmpty {
                Text("We found \(model.potentialMatches.count) potential matches")
                    .font(.headline)
                    .padding(.top)
                
                Button(action: {
                    showPotentialMatches = true
                }) {
                    Text("View Potential Matches")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 12) {
                Button(action: {
                    showCamera = true
                }) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Try Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                // Add a button to try scanning again with the same image
                if model.lastScannedImage != nil {
                    Button(action: {
                        Task {
                            await model.tryScanAgain()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Try Different Approach")
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
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
    
    private func cardResultView(_ card: Card) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Card image
                if let imageURL = URL(string: card.images.large) {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(radius: 5)
                                .padding(.horizontal)
                        } else if phase.error != nil {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.red)
                                )
                                .cornerRadius(12)
                                .padding(.horizontal)
                        } else {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.2))
                                .overlay(
                                    ProgressView()
                                )
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Card details
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(card.supertype)
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)
                        
                        if let types = card.types, !types.isEmpty {
                            ForEach(types, id: \.self) { type in
                                Text(type)
                                    .font(.headline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    if let hp = card.hp {
                        Text("HP: \(hp)")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    // Price information
                    Group {
                        Text("Market Prices")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let tcgplayer = card.tcgplayer, let prices = tcgplayer.prices {
                            if let normal = prices.normal, let market = normal.market {
                                priceRow(label: "Normal", value: market)
                            }
                            
                            if let holofoil = prices.holofoil, let market = holofoil.market {
                                priceRow(label: "Holofoil", value: market)
                            }
                            
                            if let reverseHolofoil = prices.reverseHolofoil, let market = reverseHolofoil.market {
                                priceRow(label: "Reverse Holofoil", value: market)
                            }
                            
                            Text("Last updated: \(formatDate(tcgplayer.updatedAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No price information available")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Show "Not the right card?" option if we have multiple potential matches
                    if model.potentialMatches.count > 1 {
                        Divider()
                        
                        Button(action: {
                            showPotentialMatches = true
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("Not the right card? View other matches")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    // Add to collection button
                    Button(action: {
                        if model.addToCollection() {
                            // Show success feedback
                        }
                    }) {
                        Text("Add to Collection")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.vertical)
                }
                .padding()
            }
        }
    }
    
    // View for showing potential matches
    private var potentialMatchesView: some View {
        NavigationStack {
            List {
                ForEach(model.potentialMatches.indices, id: \.self) { index in
                    let card = model.potentialMatches[index]
                    HStack {
                        if let imageURL = URL(string: card.images.small) {
                            AsyncImage(url: imageURL) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 60)
                                        .cornerRadius(4)
                                } else {
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.2))
                                        .frame(width: 60, height: 80)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name)
                                .font(.headline)
                            
                            HStack {
                                Text(card.supertype)
                                    .font(.caption)
                                
                                if let hp = card.hp {
                                    Text("• HP: \(hp)")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if index == model.selectedMatchIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectMatch(at: index)
                        showPotentialMatches = false
                    }
                }
            }
            .navigationTitle("Potential Matches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showPotentialMatches = false
                    }
                }
            }
        }
    }
    
    private func priceRow(label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text("$\(String(format: "%.2f", value))")
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString
        }
        
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: date)
    }
} 