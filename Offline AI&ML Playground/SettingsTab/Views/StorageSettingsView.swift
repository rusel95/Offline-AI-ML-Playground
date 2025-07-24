//
//  StorageSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData
import MLX

// MARK: - Storage Settings View
struct StorageSettingsView: View {
    @EnvironmentObject private var viewModel: StorageSettingsViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearHistoryAlert = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Storage Management Card
            VStack(alignment: .leading, spacing: 16) {
                // Storage usage section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Storage Used")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(viewModel.storageStatusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Clear all models section
                Button {
                    viewModel.showingClearModelsAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Models")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .onAppear {
            viewModel.refreshStorageInfo()
        }
        .alert("Clear All Models", isPresented: $viewModel.showingClearModelsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                viewModel.clearAllModels()
            }
        } message: {
            Text("This will permanently delete all downloaded AI models from your device. This action cannot be undone.")
        }
    }
    
    private func clearAllChatHistory() {
        let historyManager = ChatHistoryManager(modelContext: modelContext)
        historyManager.deleteAllConversations()
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            StorageSettingsView()
                .environmentObject(StorageSettingsViewModel())
        }
        .navigationTitle("Storage Settings")
    }
} 
