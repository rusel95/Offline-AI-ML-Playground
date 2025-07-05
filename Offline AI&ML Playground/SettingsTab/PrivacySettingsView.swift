//
//  PrivacySettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        Section("Privacy & Security") {
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.red)
                Text("Keep Chat History")
                Spacer()
                Toggle("", isOn: $settingsManager.keepChatHistory)
                    .toggleStyle(SwitchToggleStyle(tint: .red))
            }
            
            HStack {
                Image(systemName: "eye.slash")
                    .foregroundColor(.gray)
                Text("Hide Sensitive Content")
                Spacer()
                Toggle("", isOn: $settingsManager.hideSensitiveContent)
                    .toggleStyle(SwitchToggleStyle(tint: .gray))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            PrivacySettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Privacy Settings")
    }
} 