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
    @EnvironmentObject private var viewModel: AboutSettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(viewModel.versionString)
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }
                
                Divider()
                
                Text(viewModel.attribution)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            AboutSettingsView()
                .environmentObject(AboutSettingsViewModel())
        }
        .navigationTitle("About")
    }
} 
