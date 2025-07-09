//
//  StorageSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - Storage Settings View
struct StorageSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var downloadManager = ModelDownloadManager()
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearHistoryAlert = false
    @State private var showingClearModelsAlert = false
    
    var body: some View {
        Section("Storage Management") {
            // Storage usage section
            Section {
                VStack(alignment: .leading) {
                    Text("Storage Used")
                    Text("\(downloadManager.formattedStorageUsed) of \(downloadManager.formattedFreeStorage) free")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Add storage progress indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int((downloadManager.storageUsed / downloadManager.freeStorage) * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: downloadManager.storageUsed, total: downloadManager.freeStorage)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .scaleEffect(y: 0.8)
                }
            } header: {
                Text("Storage")
            }
            
            // Clear all models section
            Section {
                Button {
                    showingClearModelsAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Models")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            } header: {
                Text("Model Management")
            } footer: {
                Text("This will permanently delete all downloaded AI models from your device. This action cannot be undone.")
            }
        }
        .alert("Clear All Models", isPresented: $showingClearModelsAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllModels()
            }
        } message: {
            Text("This will permanently delete all downloaded AI models from your device. This action cannot be undone.")
        }
    }
    
    private func clearAllModels() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        
        do {
            // Get all files in models directory
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            // Delete each model file
            for fileURL in contents {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted model file: \(fileURL.lastPathComponent)")
            }
            
            // Clear the downloaded models set
            downloadManager.downloadedModels.removeAll()
            
            // Recalculate storage
            downloadManager.calculateStorageUsed()
            downloadManager.updateTotalStorage()
            
            print("✅ All models cleared successfully")
        } catch {
            print("❌ Error clearing models: \(error)")
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
            StorageSettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Storage Settings")
    }
} 