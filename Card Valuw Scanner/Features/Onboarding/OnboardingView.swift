import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @State private var currentPage = 0
    @State private var showReviewPrompt = false
    @Environment(\.appReviewService) private var appReviewService
    
    // Define the brand red color
    private let brandRed = Color(hex: "#d80015")
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color(hex: "#220033")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Navigation dots at the top
                HStack(spacing: 15) {
                    // Search icon (red for first screen)
                    Circle()
                        .fill(currentPage == 0 ? brandRed : brandRed.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                    
                    // Line connector
                    Rectangle()
                        .fill(brandRed.opacity(0.5))
                        .frame(height: 2)
                    
                    // Camera icon (red for second screen)
                    Circle()
                        .fill(currentPage == 1 ? brandRed : brandRed.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                    
                    // Line connector
                    Rectangle()
                        .fill(brandRed.opacity(0.5))
                        .frame(height: 2)
                    
                    // Chart icon (red for third screen)
                    Circle()
                        .fill(currentPage == 2 ? brandRed : brandRed.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                
                // Custom TabView with no swipe gesture
                ZStack {
                    if currentPage == 0 {
                        WelcomePageView(brandRed: brandRed)
                    } else if currentPage == 1 {
                        ScanningPageView(brandRed: brandRed)
                    } else {
                        LivePricesPageView(brandRed: brandRed)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Continue button
                Button(action: {
                    if currentPage < 2 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Show review prompt before completing onboarding
                        showReviewPrompt = true
                    }
                }) {
                    Text(currentPage == 2 ? "Try for Free" : "Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandRed) // Use brand red instead of #FF3B30
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom)
            }
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 0)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 0)
            }
            
            // Review prompt alert
            if showReviewPrompt {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ReviewPromptView(brandRed: brandRed, showReviewPrompt: $showReviewPrompt, isOnboardingCompleted: $isOnboardingCompleted)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// Review Prompt View
struct ReviewPromptView: View {
    let brandRed: Color
    @Binding var showReviewPrompt: Bool
    @Binding var isOnboardingCompleted: Bool
    @Environment(\.appReviewService) private var appReviewService
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Star icon
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            // Title
            Text("Enjoying Card Value Scanner?")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Description
            Text("We'd love to hear your feedback! Would you mind taking a moment to rate our app?")
                .font(.body)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Buttons
            HStack(spacing: 15) {
                // Not Now button
                Button(action: {
                    withAnimation {
                        showReviewPrompt = false
                        isOnboardingCompleted = true
                    }
                }) {
                    Text("Not Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(16)
                }
                
                // Rate Now button
                Button(action: {
                    // Request app review
                    appReviewService.requestReviewDuringOnboarding(force: true)
                    
                    // Complete onboarding
                    withAnimation {
                        showReviewPrompt = false
                        isOnboardingCompleted = true
                    }
                }) {
                    Text("Rate Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(brandRed)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(hex: "#220033").opacity(0.95))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.5), radius: 20)
        .frame(width: 320)
        .onAppear {
            isAnimating = true
        }
    }
}

// First Onboarding Page - Welcome with testimonial
struct WelcomePageView: View {
    // Animation states
    @State private var isAnimating = false
    @State private var showTestimonial = false
    @State private var showStars = false
    @State private var showEmojis = false
    @State private var userImageScale: CGFloat = 0.5
    @State private var userImageOpacity: Double = 0
    @State private var laurelLeftOffset: CGFloat = -50
    @State private var laurelRightOffset: CGFloat = 50
    
    // Brand red color passed from parent
    let brandRed: Color
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Welcome to Card\nValue Scanner")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top)
                .fixedSize(horizontal: false, vertical: true)
            
            // Subtitle
            Text("The most accurate and efficient way to\nunofficially track your pokemon collection")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // User testimonial section
            ZStack {
                // User image
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(20)
                            .foregroundColor(.white)
                    )
                    .scaleEffect(userImageScale)
                    .opacity(userImageOpacity)
                
                // Laurel leaves
                HStack(spacing: 160) {
                    // Left laurel
                    Image(systemName: "laurel.leading")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundColor(.white)
                        .offset(x: laurelLeftOffset)
                        .opacity(showStars ? 1 : 0)
                    
                    // Right laurel
                    Image(systemName: "laurel.trailing")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .foregroundColor(.white)
                        .offset(x: laurelRightOffset)
                        .opacity(showStars ? 1 : 0)
                }
            }
            .frame(height: 150)
            
            // Star rating
            HStack {
                Text("Love it")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(showStars ? 1 : 0)
            }
            
            HStack {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 24))
                        .opacity(showStars ? 1 : 0)
                }
            }
            .padding(.bottom, 10)
            
            // Testimonial text
            Text("\"It's so accurate I sold something for $95")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(showTestimonial ? 1 : 0)
            
            // Emoji row
            HStack(spacing: 5) {
                ForEach(0..<3) { _ in
                    Text("🤑")
                        .font(.system(size: 30))
                        .opacity(showEmojis ? 1 : 0)
                }
            }
            .padding(.bottom, 10)
            
            Spacer()
            
            // Stats at bottom
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(brandRed)
                Text("Trusted by 145,172+ Collectors")
                    .font(.system(size: 16))
                    .foregroundColor(brandRed)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animate user image
        withAnimation(.easeOut(duration: 1.0)) {
            userImageScale = 1.0
            userImageOpacity = 1.0
        }
        
        // Animate stars after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 1.0)) {
                showStars = true
            }
        }
        
        // Animate laurels
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                laurelLeftOffset = 0
                laurelRightOffset = 0
            }
        }
        
        // Animate testimonial text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.8)) {
                showTestimonial = true
            }
        }
        
        // Animate emojis
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                showEmojis = true
            }
        }
    }
}

// Second Onboarding Page - Card Scanning
struct ScanningPageView: View {
    // Animation states
    @State private var showPhone = false
    @State private var showCard = false
    @State private var showScanFrame = false
    @State private var scanningInProgress = false
    @State private var scanComplete = false
    @State private var phoneScale: CGFloat = 0.8
    @State private var cardOffset: CGFloat = 200
    @State private var scanFrameOpacity: Double = 0
    @State private var scanLinePosition: CGFloat = 0
    
    // Brand red color passed from parent
    let brandRed: Color
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Snap a Photo to\nTrack Your Cards")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top)
                .fixedSize(horizontal: false, vertical: true)
            
            // Subtitle
            Text("Quickly scan your cards to get prices,\ncertified population, pull rates and more!")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Phone with card scanning animation
            ZStack {
                // Phone outline
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 160, height: 320)
                    .scaleEffect(phoneScale)
                    .opacity(showPhone ? 1 : 0)
                
                // Phone screen
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black)
                    .frame(width: 150, height: 300)
                    .scaleEffect(phoneScale)
                    .opacity(showPhone ? 1 : 0)
                
                // Card being scanned
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 90, height: 120)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .offset(y: cardOffset)
                    .opacity(showCard ? 1 : 0)
                
                // Scanning frame
                RoundedRectangle(cornerRadius: 8)
                    .stroke(brandRed, lineWidth: 2)
                    .frame(width: 100, height: 130)
                    .opacity(showScanFrame ? 1 : 0)
                
                // Scanning line
                Rectangle()
                    .fill(brandRed.opacity(0.6))
                    .frame(width: 90, height: 2)
                    .offset(y: scanLinePosition)
                    .opacity(scanningInProgress ? 1 : 0)
                
                // Scan complete checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .opacity(scanComplete ? 1 : 0)
            }
            .frame(height: 350)
            
            Spacer()
            
            // Stats at bottom
            HStack {
                Image(systemName: "doc.viewfinder")
                    .foregroundColor(brandRed)
                Text("Scan 17,825+ Cards")
                    .font(.system(size: 16))
                    .foregroundColor(brandRed)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Show phone
        withAnimation(.easeOut(duration: 0.8)) {
            showPhone = true
            phoneScale = 1.0
        }
        
        // Show card after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCard = true
                cardOffset = 0
            }
        }
        
        // Show scan frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showScanFrame = true
                scanFrameOpacity = 1
            }
            
            // Start scanning animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    scanningInProgress = true
                }
                
                // Animate scan line
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scanLinePosition = 50
                }
                
                // Show scan complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        scanningInProgress = false
                        scanComplete = true
                    }
                }
            }
        }
    }
}

// Third Onboarding Page - Live eBay Prices
struct LivePricesPageView: View {
    // Animation states
    @State private var showPhone = false
    @State private var showCards = false
    @State private var showLiveLabel = false
    @State private var phoneScale: CGFloat = 0.8
    @State private var card1Offset: CGFloat = -200
    @State private var card2Offset: CGFloat = 200
    @State private var card3Offset: CGFloat = 400
    @State private var liveLabelScale: CGFloat = 0.5
    @State private var liveLabelOpacity: Double = 0
    @State private var pulsate = false
    @State private var headerOffset: CGFloat = -50
    @State private var subtitleOffset: CGFloat = -30
    @State private var phoneRotation: Double = -10
    @State private var phoneGlow: CGFloat = 0
    @State private var card1Rotation: Double = 15
    @State private var card2Rotation: Double = -10
    @State private var card3Rotation: Double = 20
    @State private var card1Scale: CGFloat = 0.8
    @State private var card2Scale: CGFloat = 0.8
    @State private var card3Scale: CGFloat = 0.8
    @State private var cardGlows: [CGFloat] = [0, 0, 0]
    @State private var statsOpacity: Double = 0
    @State private var statsScale: CGFloat = 0.7
    @State private var cardsHovering = false
    @State private var liveGlow: CGFloat = 0
    
    // Brand red color passed from parent
    let brandRed: Color
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Unlock Live\nMarket Prices")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top)
                .offset(y: headerOffset)
                .blur(radius: showPhone ? 0 : 10)
                .fixedSize(horizontal: false, vertical: true)
            
            // Subtitle
            Text("Maximize your collection's value with real-\ntime insights from Card Market (Subscription\nrequired)")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .offset(y: subtitleOffset)
                .blur(radius: showPhone ? 0 : 5)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // Phone with live prices animation
            ZStack {
                // Phone outline with glow effect
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 160, height: 320)
                    .scaleEffect(phoneScale)
                    .rotationEffect(Angle(degrees: phoneRotation))
                    .opacity(showPhone ? 1 : 0)
                    .shadow(color: .white, radius: phoneGlow)
                
                // Phone screen
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black)
                    .frame(width: 150, height: 300)
                    .scaleEffect(phoneScale)
                    .rotationEffect(Angle(degrees: phoneRotation))
                    .opacity(showPhone ? 1 : 0)
                
                // Live label with enhanced pulsating effect
                ZStack {
                    // Outer glow for LIVE label
                    RoundedRectangle(cornerRadius: 10)
                        .fill(brandRed.opacity(0.3))
                        .frame(width: 90, height: 50)
                        .blur(radius: liveGlow)
                        .scaleEffect(pulsate ? 1.2 : 1.0)
                    
                    // LIVE label
                    RoundedRectangle(cornerRadius: 10)
                        .fill(brandRed)
                        .frame(width: 80, height: 40)
                        .overlay(
                            Text("LIVE")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .white, radius: 1)
                        )
                        .scaleEffect(pulsate ? 1.1 : 1.0)
                }
                .position(x: 60, y: 100)
                .scaleEffect(liveLabelScale)
                .opacity(liveLabelOpacity)
                
                // Pokemon cards with enhanced effects
                Group {
                    // Card 1 (left) - yellow/orange
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.yellow, Color.orange]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 70, height: 100)
                        .shadow(color: .yellow.opacity(0.7), radius: cardGlows[0])
                        .offset(x: card1Offset, y: cardsHovering ? -5 : 0)
                        .rotationEffect(Angle(degrees: card1Rotation))
                        .scaleEffect(card1Scale)
                        .opacity(showCards ? 1 : 0)
                    
                    // Card 2 (middle) - blue/cyan
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.cyan]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 70, height: 100)
                        .shadow(color: .blue.opacity(0.7), radius: cardGlows[1])
                        .offset(x: card2Offset, y: cardsHovering ? -10 : 0)
                        .rotationEffect(Angle(degrees: card2Rotation))
                        .scaleEffect(card2Scale)
                        .opacity(showCards ? 1 : 0)
                    
                    // Card 3 (right) - green/mint
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.mint]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 70, height: 100)
                        .shadow(color: .green.opacity(0.7), radius: cardGlows[2])
                        .offset(x: card3Offset, y: cardsHovering ? -5 : 0)
                        .rotationEffect(Angle(degrees: card3Rotation))
                        .scaleEffect(card3Scale)
                        .opacity(showCards ? 1 : 0)
                }
            }
            .frame(height: 350)
            
            Spacer()
            
            // Stats with animation
            Text("Over 77,678+ Sales Tracked")
                .font(.system(size: 16))
                .foregroundColor(brandRed)
                .opacity(statsOpacity)
                .scaleEffect(statsScale)
                .shadow(color: brandRed.opacity(0.5), radius: statsOpacity > 0.5 ? 5 : 0)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Animate header and subtitle
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            headerOffset = 0
        }
        
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
            subtitleOffset = 0
        }
        
        // Show phone with rotation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            showPhone = true
            phoneScale = 1.0
            phoneRotation = 0
        }
        
        // Add glow to phone
        withAnimation(.easeInOut(duration: 1.2).delay(0.5)) {
            phoneGlow = 8
        }
        
        // Show cards with staggered animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showCards = true
            
            // Animate first card
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                card1Offset = -50
                card1Rotation = 0
                card1Scale = 1.0
            }
            
            // Add glow to first card with delay
            withAnimation(.easeInOut(duration: 1.0).delay(0.1)) {
                cardGlows[0] = 8
            }
            
            // Animate second card with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    card2Offset = 0
                    card2Rotation = 0
                    card2Scale = 1.0
                }
                
                // Add glow to second card
                withAnimation(.easeInOut(duration: 1.0).delay(0.1)) {
                    cardGlows[1] = 8
                }
            }
            
            // Animate third card with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    card3Offset = 50
                    card3Rotation = 0
                    card3Scale = 1.0
                }
                
                // Add glow to third card
                withAnimation(.easeInOut(duration: 1.0).delay(0.1)) {
                    cardGlows[2] = 8
                }
            }
            
            // Start hovering animation for cards
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    cardsHovering = true
                }
            }
        }
        
        // Show live label with enhanced effects
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                liveLabelScale = 1.0
                liveLabelOpacity = 1.0
            }
            
            // Add glow to LIVE label
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                liveGlow = 10
            }
            
            // Start pulsating animation for LIVE label
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsate = true
            }
        }
        
        // Animate stats
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                statsOpacity = 1.0
                statsScale = 1.0
            }
        }
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    OnboardingView(isOnboardingCompleted: .constant(false))
} 
