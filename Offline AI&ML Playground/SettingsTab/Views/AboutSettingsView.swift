//
//  AboutSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - About Settings View
struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var body: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
            }
            
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("Made with ❤️ by Ruslan Popesku")
                    .font(.caption)
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            AboutSettingsView()
        }
        .navigationTitle("About")
    }
} 