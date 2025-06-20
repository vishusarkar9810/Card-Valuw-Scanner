//
//  Card_Valuw_ScannerApp.swift
//  Card Valuw Scanner
//
//  Created by Vishwajeet Sarkar on 16/06/25.
//

import SwiftUI
import SwiftData

@main
struct Card_Valuw_ScannerApp: App {
    // Set up the model container for SwiftData
    var modelContainer: ModelContainer
    
    // Read dark mode preference from AppStorage
    @AppStorage("darkMode") private var darkMode = false
    
    init() {
        do {
            // Create a model container for CardEntity and CollectionEntity
            let schema = Schema([CardEntity.self, CollectionEntity.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(darkMode ? .dark : .light)
        }
        .modelContainer(modelContainer)
    }
}
