import SwiftUI

struct SubscriptionView: View {
    // MARK: - Properties
    
    @State var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @Binding var isPresented: Bool
    
    private let accentColor = Color.red
    
    // Animation states
    @State private var isAnimating = false
    @State private var cardOffset1 = CGSize(width: 0, height: 0)
    @State private var cardOffset3 = CGSize(width: 0, height: 0)
    @State private var giftScale: CGFloat = 1.0
    @State private var giftOpacity: Double = 1.0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // Header with gift box animation
                    VStack(spacing: 24) {
                        ZStack {
                            // Gift box
                            Image(systemName: "gift.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .foregroundColor(accentColor)
                                .scaleEffect(giftScale)
                                .opacity(giftOpacity)
                            
                            // Pokemon cards positioned around the gift box
                            // Card 1 - Blue card (left)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                                .frame(width: 60, height: 80)
                                .overlay(
                                    Image(systemName: "sparkles")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.white)
                                )
                                .rotationEffect(.degrees(-20))
                                .offset(cardOffset1)
                                .opacity(isAnimating ? 1 : 0)
                            
                            // Card 2 - Green card (right)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                                .frame(width: 60, height: 80)
                                .overlay(
                                    Image(systemName: "flame.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .foregroundColor(.white)
                                )
                                .rotationEffect(.degrees(20))
                                .offset(cardOffset3)
                                .opacity(isAnimating ? 1 : 0)
                        }
                        .frame(height: 200) // Fixed height container to prevent layout shifts
                        .padding(.top, 20) // Reduced top padding
                        .onAppear {
                            startAnimation()
                        }
                        
                        Text("Unlock Premium Insights")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 20) // Reduced bottom padding
                    
                    // Features list
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(PremiumFeature.allCases, id: \.self) { feature in
                            featureRow(icon: feature.iconName, text: feature.description)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    
                    // Subscription options
                    VStack(spacing: 20) {
                        // Yearly plan option with Save badge
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 0) {
                                Button(action: {
                                    viewModel.selectPlan(.yearly)
                                    viewModel.isTrialEnabled = false
                                }) {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Yearly Plan")
                                                .font(.headline)
                                        }
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .trailing) {
                                            Text(viewModel.yearlyPlanOriginalPrice)
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                                .strikethrough()
                                            
                                            Text(viewModel.yearlyPlanPrice)
                                                .font(.headline)
                                        }
                                        
                                        // Radio button
                                        ZStack {
                                            Circle()
                                                .stroke(viewModel.selectedPlan == .yearly ? accentColor : Color.gray, lineWidth: 2)
                                                .frame(width: 24, height: 24)
                                            
                                            if viewModel.selectedPlan == .yearly {
                                                Circle()
                                                    .fill(accentColor)
                                                    .frame(width: 16, height: 16)
                                            }
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color(.systemBackground))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.selectedPlan == .yearly ? accentColor : Color.clear, lineWidth: 2)
                            )
                            
                            // Save badge positioned at the top right
                            Text("SAVE \(viewModel.yearlyPlanSavings)")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(accentColor)
                                .cornerRadius(8)
                                .offset(x: -16, y: -10)
                        }
                        .padding(.horizontal)
                        
                        // Trial option
                        VStack(spacing: 0) {
                            Button(action: {
                                viewModel.selectPlan(.trial)
                                viewModel.isTrialEnabled = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("3-Day Trial")
                                            .font(.headline)
                                        
                                        Text("then \(viewModel.trialPrice) per week")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Free trial badge
                                    Text("FREE TRIAL")
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(accentColor)
                                        .cornerRadius(12)
                                    
                                    // Radio button
                                    ZStack {
                                        Circle()
                                            .stroke(viewModel.selectedPlan == .trial ? accentColor : Color.gray, lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                        
                                        if viewModel.selectedPlan == .trial {
                                            Circle()
                                                .fill(accentColor)
                                                .frame(width: 16, height: 16)
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6).opacity(0.5))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .background(Color(.systemGray6).opacity(0.5))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.selectedPlan == .trial ? accentColor : Color.clear, lineWidth: 2)
                        )
                        .padding(.horizontal)
                        
                        // Trial toggle
                        HStack {
                            Text("Free Trial Enabled")
                                .font(.headline)
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.isTrialEnabled)
                                .labelsHidden()
                                .tint(.green)
                                .onChange(of: viewModel.isTrialEnabled) { newValue in
                                    if newValue {
                                        viewModel.selectPlan(.trial)
                                    } else {
                                        viewModel.selectPlan(.yearly)
                                    }
                                }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 30)
                    
                    // Try for free button
                    Button(action: {
                        Task {
                            if viewModel.selectedPlan == .yearly {
                                await viewModel.purchaseYearlyPlan()
                            } else {
                                await viewModel.startFreeTrial()
                            }
                            
                            // If purchase was successful, dismiss the view
                            if viewModel.isPremium {
                                isPresented = false
                            }
                        }
                    }) {
                        HStack {
                            Text(viewModel.selectedPlan == .yearly ? "Purchase" : "Try for Free")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentColor)
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                    
                    // Restore link
                    Button("Restore") {
                        Task {
                            await viewModel.restorePurchases()
                            
                            // If restore was successful, dismiss the view
                            if viewModel.isPremium {
                                isPresented = false
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    .padding(.bottom)
                    
                    // Error message (if any)
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                    
                    // Terms and Privacy
                    HStack {
                        Button("Terms of Use & Privacy Policy") {
                            // Open terms and privacy
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                // Ensure toggle and selected plan are in sync when view appears
                viewModel.isTrialEnabled = (viewModel.selectedPlan == .trial)
                
                // Debug the trial duration
                print("Trial duration from viewModel: \(viewModel.trialDuration)")
            }
            
            // Close button (top right)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(.systemGray6).opacity(0.8))
                            .clipShape(Circle())
                            .padding(.top, 50) // Increased padding for better visibility
                    }
                    .padding(.trailing, 16)
                }
                Spacer()
            }
            
            // Loading overlay
            if viewModel.isLoading {
                Color.black.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // MARK: - Animation Methods
    
    private func startAnimation() {
        // Reset animation state
        resetAnimationState()
        
        // Initial positions - cards are hidden inside the gift box
        cardOffset1 = .zero
        cardOffset3 = .zero
        
        // Start animation sequence
        withAnimation(.easeInOut(duration: 0.5)) {
            giftScale = 1.1
        }
        
        // Animate cards appearing in their final positions
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0).delay(0.5)) {
            isAnimating = true
            
            // Position cards around the gift box as shown in the screenshot
            // Left card (blue)
            cardOffset1 = CGSize(width: -120, height: 20)
            
            // Right card (green)
            cardOffset3 = CGSize(width: 120, height: 20)
            
            giftScale = 1.0
        }
        
        // Reset and repeat animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                resetAnimationState()
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                startAnimation()
            }
        }
    }
    
    private func resetAnimationState() {
        isAnimating = false
        cardOffset1 = .zero
        cardOffset3 = .zero
        giftScale = 1.0
    }
    
    // MARK: - Helper Views
    
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(accentColor)
            
            Text(text)
                .font(.title3)
        }
    }
}

struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView(viewModel: SubscriptionViewModel(), isPresented: .constant(true))
    }
} 