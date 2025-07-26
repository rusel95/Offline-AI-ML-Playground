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
            
            // GGUF Test Button
            Button(action: {
                Task {
                    await TestPublicGGUF.testSmolLMDownload()
                }
            }) {
                HStack {
                    Image(systemName: "testtube.2")
                        .font(.title3)
                    Text("Test GGUF Loading")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Tests GGUF model download and loading functionality")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            // Download Debug Button
            Button(action: {
                Task {
                    await DownloadDebugger.testDirectDownload()
                    await DownloadDebugger.checkRepositoryStructure()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text("Debug Downloads")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Debug download issues and check repository structure")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
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
