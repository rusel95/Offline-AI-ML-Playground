//
//  UserDefaults+ModelPersistence.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation

// MARK: - UserDefaults Extension for Model Persistence
extension UserDefaults {
    /// Keys used for storing model persistence data
    private enum Keys {
        static let lastSelectedModelID = "lastSelectedModelID"
    }
    
    /// The ID of the last selected AI model
    /// This allows the app to restore the user's model preference across app launches
    var lastSelectedModelID: String? {
        get { string(forKey: Keys.lastSelectedModelID) }
        set { set(newValue, forKey: Keys.lastSelectedModelID) }
    }
}

#Preview("UserDefaults Extension") {
    VStack(spacing: 20) {
        Text("UserDefaults Model Persistence")
            .font(.title)
            .fontWeight(.bold)
        
        Text("This extension provides persistent storage for model preferences:")
            .font(.subheadline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("• lastSelectedModelID - Stores the user's preferred model")
            Text("• Automatically persists across app launches")
            Text("• Uses UserDefaults for lightweight storage")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        
        // Demo the functionality
        let demoID = "llama-2-7b-chat-q4"
        Text("Demo: Setting model ID to '\(demoID)'")
            .font(.caption)
            .padding()
            .background(.blue.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
} 