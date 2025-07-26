//
//  ModelFileManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 26.07.2025.
//

import Foundation

/// Centralized file manager for AI models
/// Handles all file operations: saving, loading, checking existence, deleting
/// Uses model.id as the primary identifier for file storage
public class ModelFileManager: NSObject, ObservableObject {
    // MARK: - Singleton
    public static let shared = ModelFileManager()
    
    // MARK: - Properties
    @Published public var downloadedModels: Set<String> = []
    
    private let documentsDirectory: URL
    public let modelsDirectory: URL
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    private override init() {
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.modelsDirectory = documentsDirectory.appendingPathComponent("Models")
        
        super.init()
        
        setupDirectories()
        refreshDownloadedModels()
    }
    
    // MARK: - Setup
    private func setupDirectories() {
        do {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            print("📁 Models directory ready at: \(modelsDirectory.path)")
        } catch {
            print("❌ Failed to create models directory: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get the file path for a model
    public func getModelPath(for modelId: String) -> URL {
        // Use model ID directly as filename with .gguf extension
        return modelsDirectory.appendingPathComponent("\(modelId).gguf")
    }
    
    /// Check if a model is downloaded
    public func isModelDownloaded(_ modelId: String) -> Bool {
        let path = getModelPath(for: modelId)
        return fileManager.fileExists(atPath: path.path)
    }
    
    /// Save a downloaded file to the models directory
    public func saveDownloadedFile(from temporaryURL: URL, for modelId: String) async throws {
        let destinationURL = getModelPath(for: modelId)
        
        // Ensure the file exists at temporary location
        guard fileManager.fileExists(atPath: temporaryURL.path) else {
            throw ModelFileError.fileNotFound(temporaryURL.path)
        }
        
        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
                print("🔄 Removed existing file at destination")
            }
            
            // Move the file (this will also remove the source file)
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            print("✅ Model saved successfully: \(modelId) -> \(destinationURL.path)")
            
            // Verify the file was saved
            if let size = getModelSize(modelId) {
                print("📊 Verified saved file size: \(formatBytes(size))")
            }
            
            // Update downloaded models set
            await MainActor.run { [weak self] in
                self?.downloadedModels.insert(modelId)
            }
        } catch {
            print("❌ Failed to save model: \(error)")
            throw ModelFileError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Delete a model file
    public func deleteModel(_ modelId: String) throws {
        let path = getModelPath(for: modelId)
        
        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
            print("🗑️ Deleted model: \(modelId)")
            
            // Update downloaded models set
            DispatchQueue.main.async { [weak self] in
                self?.downloadedModels.remove(modelId)
            }
        }
    }
    
    /// Get the size of a downloaded model
    public func getModelSize(_ modelId: String) -> Int64? {
        let path = getModelPath(for: modelId)
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Get total storage used by all models
    public func getTotalStorageUsed() -> Int64 {
        var totalSize: Int64 = 0
        
        for modelId in downloadedModels {
            if let size = getModelSize(modelId) {
                totalSize += size
            }
        }
        
        return totalSize
    }
    
    /// Refresh the list of downloaded models
    public func refreshDownloadedModels() {
        do {
            let contents = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            
            let modelIds = contents.compactMap { url -> String? in
                let filename = url.lastPathComponent
                if filename.hasSuffix(".gguf") {
                    return String(filename.dropLast(5)) // Remove .gguf extension
                }
                return nil
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.downloadedModels = Set(modelIds)
                print("📊 Found \(modelIds.count) downloaded models")
            }
        } catch {
            print("❌ Failed to refresh downloaded models: \(error)")
        }
    }
    
    /// Get all downloaded model files with their sizes
    public func getDownloadedModelInfo() -> [(modelId: String, size: Int64)] {
        var modelInfo: [(String, Int64)] = []
        
        for modelId in downloadedModels {
            if let size = getModelSize(modelId) {
                modelInfo.append((modelId, size))
            }
        }
        
        return modelInfo.sorted { $0.0 < $1.0 }
    }
    
    // MARK: - Debug Methods
    
    /// Print debug information about the models directory
    public func printDebugInfo() {
        print("\n🔍 ModelFileManager Debug Info:")
        print("📁 Models directory: \(modelsDirectory.path)")
        print("📊 Downloaded models: \(downloadedModels)")
        print("💾 Total storage used: \(formatBytes(getTotalStorageUsed()))")
        
        for (modelId, size) in getDownloadedModelInfo() {
            print("  - \(modelId): \(formatBytes(size))")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Error Types
public enum ModelFileError: LocalizedError {
    case fileNotFound(String)
    case saveFailed(String)
    case deleteFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at: \(path)"
        case .saveFailed(let reason):
            return "Failed to save model: \(reason)"
        case .deleteFailed(let reason):
            return "Failed to delete model: \(reason)"
        }
    }
}