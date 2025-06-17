import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    
    @AppStorage("username") private var username = ""
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("scanQuality") private var scanQuality = "High"
    
    private let scanQualityOptions = ["Low", "Medium", "High"]
    
    @State private var showingDeleteConfirmation = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Username", text: $username)
                }
                
                Section(header: Text("Appearance")) {
                    Toggle("Dark Mode", isOn: $darkMode)
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    
                    if notificationsEnabled {
                        Toggle("Price Alerts", isOn: .constant(true))
                        Toggle("New Set Releases", isOn: .constant(true))
                    }
                }
                
                Section(header: Text("Scanner Settings")) {
                    Picker("Scan Quality", selection: $scanQuality) {
                        ForEach(scanQualityOptions, id: \.self) { quality in
                            Text(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Toggle("Auto-Save Scanned Cards", isOn: .constant(true))
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