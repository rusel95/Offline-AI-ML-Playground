//
//  StorageSettingsViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine
import SwiftData

@MainActor
class StorageSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var storageUsed: Double = 0
    @Published var mlxStorageUsed: Double = 0
    @Published var freeStorage: Double = 0
    @Published var totalStorage: Double = 0
    @Published var isCalculatingStorage = false
    @Published var showingClearModelsAlert = false
    
    // MARK: - Dependencies
    private let downloadManager: ModelDownloadManager
    private let inferenceManager: AIInferenceManager
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var totalStorageUsed: Double {
        storageUsed + mlxStorageUsed
    }
    
    var formattedTotalStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalStorageUsed), countStyle: .file)
    }
    
    var formattedFreeStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorage), countStyle: .file)
    }
    
    var storageStatusMessage: String {
        "\(formattedTotalStorageUsed) | \(formattedFreeStorage) free left"
    }
    
    // MARK: - Initialization
    init() {
        self.downloadManager = ModelDownloadManager()
        self.inferenceManager = AIInferenceManager()
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind download manager storage values
        downloadManager.$storageUsed
            .receive(on: DispatchQueue.main)
            .assign(to: &$storageUsed)
        
        downloadManager.$freeStorage
            .receive(on: DispatchQueue.main)
            .assign(to: &$freeStorage)
    }
    
    // MARK: - Public Methods
    func refreshStorageInfo() {
        Task {
            isCalculatingStorage = true
            
            // Calculate regular models storage
            downloadManager.calculateStorageUsed()
            downloadManager.updateTotalStorage()
            
            // Calculate MLX models storage
            mlxStorageUsed = await calculateMLXStorageUsed()
            
            isCalculatingStorage = false
        }
    }
    
    func clearAllModels() {
        Task {
            do {
                // Clear regular models
                try await clearRegularModels()
                
                // Clear MLX models
                try await clearMLXModels()
                
                // Force refresh of ModelFileManager's cache
                ModelFileManager.shared.refreshDownloadedModels()
                
                // Refresh storage info
                refreshStorageInfo()
                
                print("✅ All models cleared successfully")
            } catch {
                print("❌ Error clearing models: \(error)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func calculateMLXStorageUsed() async -> Double {
        let mlxDir = inferenceManager.getModelDownloadDirectory()
        guard FileManager.default.fileExists(atPath: mlxDir.path) else { return 0 }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: mlxDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
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
                let contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
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
    
    private func clearRegularModels() async throws {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        
        // Get all files in models directory
        let contents = try FileManager.default.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        )
        
        // Delete each model file
        for fileURL in contents {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ Deleted model file: \(fileURL.lastPathComponent)")
        }
        
        // Clear the downloaded models set
        downloadManager.downloadedModels.removeAll()
    }
    
    private func clearMLXModels() async throws {
        let mlxDir = inferenceManager.getModelDownloadDirectory()
        
        do {
            let mlxContents = try FileManager.default.contentsOfDirectory(
                at: mlxDir,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in mlxContents {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted MLX model: \(fileURL.lastPathComponent)")
            }
        } catch {
            print("❌ Error clearing MLX models: \(error)")
            throw error
        }
    }
}
