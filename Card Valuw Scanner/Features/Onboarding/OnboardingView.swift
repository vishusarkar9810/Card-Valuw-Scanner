import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingCompleted: Bool
    @State private var currentPage = 0
    
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
                HStack(spacing: 20) {
                    // Search icon (red for first screen)
                    Circle()
                        .fill(currentPage == 0 ? Color.red : Color.red.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                        )
                    
                    // Line connector
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(height: 2)
                    
                    // Camera icon (red for second screen)
                    Circle()
                        .fill(currentPage == 1 ? Color.red : Color.red.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                        )
                    
                    // Line connector
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(height: 2)
                    
                    // Chart icon (red for third screen)
                    Circle()
                        .fill(currentPage == 2 ? Color.red : Color.red.opacity(0.5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.white)
                        )
                }
                .padding(.top, 50)
                .padding(.bottom, 20)
                
                TabView(selection: $currentPage) {
                    // First page - Welcome with testimonial
                    WelcomePageView()
                        .tag(0)
                    
                    // Second page - Card scanning
                    ScanningPageView()
                        .tag(1)
                    
                    // Third page - Live eBay prices
                    LivePricesPageView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                Spacer()
                
                // Continue button
                Button(action: {
                    if currentPage < 2 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        // Complete onboarding
                        isOnboardingCompleted = true
                    }
                }) {
                    Text(currentPage == 2 ? "Try for Free" : "Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#FF3B30")) // Bright red
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
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
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Header
            Text("Welcome to Card\nValue Scanner")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            // Subtitle
            Text("The most accurate and efficient way to\nunofficially track your pokemon collection")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
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
                HStack(spacing: 200) {
                    // Left laurel
                    Image(systemName: "laurel.leading")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundColor(.white)
                        .offset(x: laurelLeftOffset)
                        .opacity(showStars ? 1 : 0)
                    
                    // Right laurel
                    Image(systemName: "laurel.trailing")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
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
                    .foregroundColor(.red)
                Text("Trusted by 145,172+ Collectors")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .padding(.bottom)
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
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Header
            Text("Snap a Photo to\nTrack Your Cards")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            // Subtitle
            Text("Quickly scan your cards to get prices,\ncertified population, pull rates and more!")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Phone with card scanning animation
            ZStack {
                // Phone outline
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 200, height: 400)
                    .scaleEffect(phoneScale)
                    .opacity(showPhone ? 1 : 0)
                
                // Phone screen
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black)
                    .frame(width: 190, height: 380)
                    .scaleEffect(phoneScale)
                    .opacity(showPhone ? 1 : 0)
                
                // Card being scanned
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 120, height: 160)
                    .shadow(color: .white.opacity(0.5), radius: 10)
                    .offset(y: cardOffset)
                    .opacity(showCard ? 1 : 0)
                
                // Scanning frame
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: 130, height: 170)
                    .opacity(showScanFrame ? 1 : 0)
                
                // Scanning line
                Rectangle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 120, height: 2)
                    .offset(y: scanLinePosition)
                    .opacity(scanningInProgress ? 1 : 0)
                
                // Scan complete checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .opacity(scanComplete ? 1 : 0)
            }
            .frame(height: 400)
            
            Spacer()
            
            // Stats at bottom
            HStack {
                Image(systemName: "doc.viewfinder")
                    .foregroundColor(.red)
                Text("Scan 17,825+ Cards")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
            .padding(.bottom)
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
                    scanLinePosition = 70
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
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Header
            Text("Unlock Live\neBay Prices")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 10)
            
            // Subtitle
            Text("Maximize your collection's value with real-\ntime insights from eBay (Subscription\nrequired)")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            // Phone with live prices animation
            ZStack {
                // Phone outline
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 180, height: 360)
                    .scaleEffect(phoneScale)
                    .opacity(showPhone ? 1 : 0)
                
                // Phone screen
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.black)
                    .frame(width: 170, height: 340)
                    .scaleEffect(phoneScale)
                    .opacity(showPhone ? 1 : 0)
                
                // Live label
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.red)
                        .frame(width: 80, height: 40)
                        .overlay(
                            Text("LIVE")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(pulsate ? 1.1 : 1.0)
                }
                .position(x: 70, y: 120)
                .scaleEffect(liveLabelScale)
                .opacity(liveLabelOpacity)
                
                // Pokemon cards
                Group {
                    // Card 1 (left)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.yellow, Color.orange]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 80, height: 120)
                        .shadow(color: .white.opacity(0.3), radius: 5)
                        .offset(x: card1Offset, y: 0)
                        .opacity(showCards ? 1 : 0)
                    
                    // Card 2 (middle)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.cyan]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 80, height: 120)
                        .shadow(color: .white.opacity(0.3), radius: 5)
                        .offset(x: card2Offset, y: 0)
                        .opacity(showCards ? 1 : 0)
                    
                    // Card 3 (right)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.mint]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 80, height: 120)
                        .shadow(color: .white.opacity(0.3), radius: 5)
                        .offset(x: card3Offset, y: 0)
                        .opacity(showCards ? 1 : 0)
                }
            }
            .frame(height: 400)
            
            Spacer()
            
            // Stats
            Text("Over 77,678+ Sales Tracked")
                .font(.system(size: 16))
                .foregroundColor(.red)
                .padding(.bottom)
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
        
        // Show cards after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showCards = true
                card1Offset = -60
                card2Offset = 0
                card3Offset = 60
            }
        }
        
        // Show live label
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                liveLabelScale = 1.0
                liveLabelOpacity = 1.0
            }
            
            // Start pulsating animation
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsate = true
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