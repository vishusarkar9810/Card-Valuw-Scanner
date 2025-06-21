import SwiftUI

struct SubscriptionView: View {
    // MARK: - Properties
    
    @ObservedObject var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) private var presentationMode
    @Binding var isPresented: Bool
    
    private let accentColor = Color.red
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background color
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // Header with gift box
                    VStack(spacing: 24) {
                        // Use SF Symbol as fallback
                        Image(systemName: "gift.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .foregroundColor(accentColor)
                            .padding(.top, 60) // Extra padding for status bar
                        
                        Text("Unlock Premium Insights")
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 30)
                    
                    // Features list
                    VStack(alignment: .leading, spacing: 22) {
                        featureRow(icon: "chart.line.uptrend.xyaxis.circle.fill", text: "Indepth market analysis")
                        featureRow(icon: "magnifyingglass.circle.fill", text: "Live eBay prices & sale trends")
                        featureRow(icon: "checkmark.circle.fill", text: "Valuations by grade & edition")
                        featureRow(icon: "folder.fill.badge.plus", text: "Add unlimited collections")
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
                                        Text("\(viewModel.trialDuration) Trial")
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
                        if viewModel.selectedPlan == .yearly {
                            viewModel.purchaseYearlyPlan()
                        } else {
                            viewModel.startFreeTrial()
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
                        viewModel.restorePurchases()
                    }
                    .foregroundColor(.blue)
                    .padding(.bottom)
                    
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