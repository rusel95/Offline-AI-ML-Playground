//
//  AdvancedSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    private var savedModelID: String? {
        UserDefaults.standard.lastSelectedModelID
    }
    
    var body: some View {
        Section("Advanced") {
            HStack {
                Image(systemName: "hammer.fill")
                    .foregroundColor(.orange)
                Text("Developer Mode")
                Spacer()
                Toggle("", isOn: $settingsManager.developerMode)
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            
            // Model Preference Management
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("Saved Model Preference")
                    Spacer()
                }
                
                if let modelID = savedModelID {
                    HStack {
                        Text("Model: \(String(modelID.prefix(20)))\(modelID.count > 20 ? "..." : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fontDesign(.monospaced)
                        
                        Spacer()
                        
                        Button("Reset") {
                            UserDefaults.standard.lastSelectedModelID = nil
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                } else {
                    Text("No saved preference")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if settingsManager.developerMode {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                    Text("Export Logs")
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            AdvancedSettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Advanced Settings")
    }
} 