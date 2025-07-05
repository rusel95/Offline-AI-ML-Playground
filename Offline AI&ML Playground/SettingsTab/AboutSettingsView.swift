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
    var body: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Version")
                Spacer()
                Text("1.0.0 (1)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                Text("Made with love by Ruslan Popesku")
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