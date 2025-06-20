import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    
    @AppStorage("darkMode") private var darkMode = false
    
    @State private var showingDeleteConfirmation = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        showPrivacyPolicy = true
                    }
                    
                    Button("Terms of Service") {
                        showTermsOfService = true
                    }
                }
                
                Section {
                    Button("Clear Cache") {
                        // Clear cache implementation
                    }
                    
                    Button("Delete All Data") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                Section {
                    Text("Pokémon, the Poké Ball and Pokémon Trading Cards are registered trademarks of Nintendo Creatures Game Freak. All rights to their respective copyright holders. This app is not affiliated with, sponsored or endorsed by, or in any way associated with The Pokemon Company International inc. / Nintendo/ Creatures Inc. / GAME FREAK inc")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .alert("Delete All Data", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    // Delete all data implementation
                }
            } message: {
                Text("Are you sure you want to delete all your collection data? This action cannot be undone.")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView(isPresented: $showPrivacyPolicy)
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView(isPresented: $showTermsOfService)
            }
        }
    }
}

struct PrivacyPolicyView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("Last Updated: June 20, 2024")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    Text("This Privacy Policy describes how we collect, use, and disclose your personal information when you use our Pokémon Card Scanner app.")
                        .padding(.bottom, 10)
                    
                    Text("Information We Collect")
                        .font(.headline)
                    
                    Text("• Camera data when scanning cards (not stored on our servers)\n• Collection information stored locally on your device\n• App usage statistics to improve our service")
                    
                    Text("How We Use Your Information")
                        .font(.headline)
                    
                    Text("• To provide and improve our card scanning service\n• To maintain and enhance your collection tracking features\n• To analyze app performance and user experience")
                    
                    Text("Third-Party Services")
                        .font(.headline)
                    
                    Text("We use the Pokémon TCG API to retrieve card information. Please refer to their privacy policy for more information:")
                    
                    Link("Pokémon TCG API Privacy Policy", destination: URL(string: "https://pokemontcg.io/privacy")!)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct TermsOfServiceView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Terms of Service")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("Last Updated: June 20, 2024")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                    
                    Text("By downloading or using the Pokémon Card Scanner app, you agree to be bound by these Terms of Service.")
                        .padding(.bottom, 10)
                    
                    Text("License")
                        .font(.headline)
                    
                    Text("We grant you a limited, non-exclusive, non-transferable, revocable license to use the Pokémon Card Scanner app for your personal, non-commercial purposes.")
                    
                    Text("Restrictions")
                        .font(.headline)
                    
                    Text("You agree not to:\n• Modify, distribute, or create derivative works of the app\n• Use the app for any illegal purpose\n• Attempt to decompile or reverse engineer the app\n• Use the app to infringe on intellectual property rights")
                    
                    Text("Disclaimer")
                        .font(.headline)
                    
                    Text("This app is not affiliated with, endorsed by, or sponsored by Nintendo, The Pokémon Company, or Game Freak. All Pokémon content and materials are trademarks and copyrights of their respective owners.")
                    
                    Text("For the full terms of service, please visit:")
                    
                    Link("Full Terms of Service", destination: URL(string: "https://pokemoncardscanner.com/terms")!)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 