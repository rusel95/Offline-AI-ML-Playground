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
    @StateObject private var downloadManager = ModelDownloadManager()
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearHistoryAlert = false
    @State private var showingClearModelsAlert = false
    
    @StateObject private var inferenceManager = AIInferenceManager()
    
    var body: some View {
        VStack(spacing: 16) {
            // Storage Management Card
            VStack(alignment: .leading, spacing: 16) {
                // Storage usage section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Storage Used")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(formattedTotalStorageUsed) | \(downloadManager.formattedFreeStorage) free left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Clear all models section
                Button {
                    showingClearModelsAlert = true
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
            downloadManager.calculateStorageUsed()
            downloadManager.updateTotalStorage()
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
    
    private var formattedTotalStorageUsed: String {
        let modelsUsed = downloadManager.storageUsed
        let mlxUsed = calculateMLXStorageUsed()
        let totalUsed = modelsUsed + mlxUsed
        return ByteCountFormatter.string(fromByteCount: Int64(totalUsed), countStyle: .file)
    }
    
    private func calculateMLXStorageUsed() -> Double {
        let mlxDir = inferenceManager.getModelDownloadDirectory()
        guard FileManager.default.fileExists(atPath: mlxDir.path) else { return 0 }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: mlxDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            let totalSize = contents.reduce(Int64(0)) { total, url in
                total + recursiveSize(for: url)
            }
            return Double(totalSize)
        } catch {
            print("Error calculating MLX storage: \(error)")
            return 0
        }
    }
    
    private func recursiveSize(for url: URL) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if isDir.boolValue {
            do {
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                return contents.reduce(Int64(0)) { $0 + recursiveSize(for: $1) }
            } catch {
                return 0
            }
        } else {
            do {
                let attributes = try url.resourceValues(forKeys: [.fileSizeKey])
                return Int64(attributes.fileSize ?? 0)
            } catch {
                return 0
            }
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
            
            // Add for MLXModels
            let mlxDir = inferenceManager.getModelDownloadDirectory()
            do {
                let mlxContents = try FileManager.default.contentsOfDirectory(at: mlxDir, includingPropertiesForKeys: nil)
                for fileURL in mlxContents {
                    try FileManager.default.removeItem(at: fileURL)
                    print("🗑️ Deleted MLX model: \(fileURL.lastPathComponent)")
                }
            } catch {
                print("❌ Error clearing MLX models: \(error)")
            }
            
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
            StorageSettingsView()
        }
        .navigationTitle("Storage Settings")
    }
} 
