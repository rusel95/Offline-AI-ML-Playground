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