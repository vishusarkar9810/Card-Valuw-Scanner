import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    
    @AppStorage("darkMode") private var darkMode = false
    
    @State private var showingDeleteConfirmation = false
    
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
                    
                    NavigationLink("Privacy Policy") {
                        Text("Privacy Policy Content")
                            .padding()
                    }
                    
                    NavigationLink("Terms of Service") {
                        Text("Terms of Service Content")
                            .padding()
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
        }
    }
} 