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
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Failed to get documents directory")
        }
        self.documentsDirectory = documentsDir
        self.modelsDirectory = documentsDirectory.appendingPathComponent("Models")
        
        super.init()
        
        setupDirectories()
        
        // Don't scan file system on init - only refresh when explicitly needed
        // This avoids the main thread hang when the app starts
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
        // Use model ID directly as filename
        // MLX models typically download as directories with multiple files
        return modelsDirectory.appendingPathComponent(modelId)
    }
    
    /// Get the MLX model directory for a given model ID
    public func getMLXModelDirectory(for modelId: String) -> URL {
        // Map model ID to MLX repository name
        let mlxRepoName = mapModelIdToMLXRepo(modelId)
        
        return modelsDirectory
            .appendingPathComponent("models")
            .appendingPathComponent("mlx-community")
            .appendingPathComponent(mlxRepoName)
    }
    
    /// Map model ID to MLX repository name
    private func mapModelIdToMLXRepo(_ modelId: String) -> String {
        // This should match the mapping in SharedModelManager
        let repoMapping: [String: String] = [
            "qwen2.5-0.5b": "Qwen2.5-0.5B-Instruct-4bit",
            "qwen2.5-1.5b": "Qwen2.5-1.5B-Instruct-4bit",
            "qwen2.5-3b": "Qwen2.5-3B-Instruct-4bit",
            "smollm-135m": "SmolLM-135M-Instruct-4bit",
            "smollm-360m": "SmolLM-360M-Instruct-4bit",
            "smollm-1.7b": "SmolLM-1.7B-Instruct-4bit",
            "tinyllama-1.1b": "TinyLlama-1.1B-Chat-v1.0-4bit",
            "deepseek-coder-1.3b": "deepseek-coder-1.3b-instruct-4bit",
            "openelm-1.1b": "OpenELM-1_1B-Instruct-4bit",
            "llama-3.2-1b": "Llama-3.2-1B-Instruct-4bit",
            "deepseek-r1-distill-qwen-1.5b": "DeepSeek-R1-Distill-Qwen-1.5B-4bit",
            "gemma-2b": "gemma-2b-it-4bit",

            "phi-3.5-mini": "Phi-3.5-mini-instruct-4bit",
            "openelm-270m": "OpenELM-270M-Instruct-4bit"
        ]
        
        return repoMapping[modelId] ?? modelId
    }
    
    /// Check if a model is downloaded
    public func isModelDownloaded(_ modelId: String) -> Bool {
        // Direct file system check - fast and accurate
        let path = getModelPath(for: modelId)
        if fileManager.fileExists(atPath: path.path) {
            return true
        }
        
        // For MLX models, check the MLX directory structure
        // This helps if refreshDownloadedModels hasn't been called yet
        let mlxModelsDir = modelsDirectory.appendingPathComponent("models/mlx-community")
        if let mlxContents = try? fileManager.contentsOfDirectory(at: mlxModelsDir, includingPropertiesForKeys: nil) {
            for modelDir in mlxContents {
                let dirName = modelDir.lastPathComponent
                if let mappedId = mapMLXRepoToModelId(dirName), mappedId == modelId {
                    // Check if model.safetensors exists
                    let modelFile = modelDir.appendingPathComponent("model.safetensors")
                    if fileManager.fileExists(atPath: modelFile.path) {
                        return true
                    }
                }
            }
        }
        
        return false
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
            _ = await MainActor.run { [weak self] in
                self?.downloadedModels.insert(modelId)
            }
        } catch {
            print("❌ Failed to save model: \(error)")
            throw ModelFileError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Delete a model file
    public func deleteModel(_ modelId: String) throws {
        // Remove marker file (simple path)
        let markerPath = getModelPath(for: modelId)
        if fileManager.fileExists(atPath: markerPath.path) {
            try fileManager.removeItem(at: markerPath)
            print("🗑️ Deleted marker for model: \(modelId)")
        }

        // Remove MLX directory (real files)
        let mlxDir = getMLXModelDirectory(for: modelId)
        if fileManager.fileExists(atPath: mlxDir.path) {
            do {
                try fileManager.removeItem(at: mlxDir)
                print("🗑️ Deleted MLX directory for model: \(modelId)")
            } catch {
                print("⚠️ Failed to delete MLX directory for \(modelId): \(error)")
                throw ModelFileError.deleteFailed("Could not delete MLX directory: \(error.localizedDescription)")
            }
        }

        // Update downloaded models set
        DispatchQueue.main.async { [weak self] in
            self?.downloadedModels.remove(modelId)
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
    
    /// Refresh the list of downloaded models asynchronously
    public func refreshDownloadedModelsAsync() async {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .background) {
                self.refreshDownloadedModelsSync()
                continuation.resume()
            }
        }
    }
    
    /// Refresh the list of downloaded models (synchronous version for compatibility)
    public func refreshDownloadedModels() {
        Task {
            await refreshDownloadedModelsAsync()
        }
    }
    
    /// Internal synchronous refresh implementation
    private func refreshDownloadedModelsSync() {
        do {
            var modelIds: Set<String> = []
            
            // Check our simple download structure
            let contents = try fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            
            for url in contents {
                let filename = url.lastPathComponent
                
                // Skip the MLX models directory as we'll check it separately
                if filename == "models" {
                    continue
                }
                
                // Check for marker files that indicate a download
                if fileManager.fileExists(atPath: url.path) {
                    // Could be a marker file with model ID as name
                    modelIds.insert(filename)
                }
            }
            
            // Also check MLX models directory structure
            let mlxModelsDir = modelsDirectory.appendingPathComponent("models")
            if fileManager.fileExists(atPath: mlxModelsDir.path) {
                // Check for mlx-community subdirectory
                let mlxCommunityDir = mlxModelsDir.appendingPathComponent("mlx-community")
                if fileManager.fileExists(atPath: mlxCommunityDir.path) {
                    let mlxContents = try fileManager.contentsOfDirectory(at: mlxCommunityDir, includingPropertiesForKeys: nil)
                    
                    for modelDir in mlxContents where FileManager.default.isDirectory(at: modelDir) {
                        let dirName = modelDir.lastPathComponent
                        print("🔍 Found MLX model directory: \(dirName)")
                        
                        // Check if model.safetensors exists to confirm it's downloaded
                        let modelFile = modelDir.appendingPathComponent("model.safetensors")
                        if fileManager.fileExists(atPath: modelFile.path) {
                            // Map from repo path to model ID
                            if let modelId = mapMLXRepoToModelId(dirName) {
                                print("✅ Mapped \(dirName) -> \(modelId)")
                                modelIds.insert(modelId)
                            } else {
                                print("⚠️ No mapping found for: \(dirName)")
                            }
                        }
                    }
                }
            }
            
            Task { @MainActor [weak self] in
                self?.downloadedModels = modelIds
                print("📊 Found \(modelIds.count) downloaded models: \(modelIds)")
            }
        } catch {
            print("❌ Failed to refresh downloaded models: \(error)")
        }
    }
    
    // Map MLX repository paths to our model IDs
    private func mapMLXRepoToModelId(_ repoPath: String) -> String? {
        // This is a reverse mapping - ideally should be stored centrally
        let mappings: [String: String] = [
            "SmolLM-135M-Instruct-4bit": "smollm-135m",
            "SmolLM-360M-Instruct-4bit": "smollm-360m",
            "SmolLM-1.7B-Instruct-4bit": "smollm-1.7b",
            "TinyLlama-1.1B-Chat-v1.0-4bit": "tinyllama-1.1b",
            "Qwen2.5-0.5B-Instruct-4bit": "qwen2.5-0.5b",
            "Qwen2.5-1.5B-Instruct-4bit": "qwen2.5-1.5b",
            "Qwen2.5-3B-Instruct-4bit": "qwen2.5-3b",
            "deepseek-coder-1.3b-instruct-4bit": "deepseek-coder-1.3b",
            "gemma-2b-it-4bit": "gemma-2b",
            "phi-2-4bit": "phi-2",
            "OpenELM-1_1B-Instruct-4bit": "openelm-1.1b",
            "Llama-3.2-1B-Instruct-4bit": "llama-3.2-1b"
        ]
        
        // Check direct mapping
        if let modelId = mappings[repoPath] {
            return modelId
        }
        
        // Also check if the directory name IS the model ID (simplified names)
        let simplifiedMappings = [
            "smollm-135m": "smollm-135m",
            "smollm-360m": "smollm-360m",
            "smollm-1.7b": "smollm-1.7b",
            "tinyllama-1.1b": "tinyllama-1.1b",
            "qwen2.5-0.5b": "qwen2.5-0.5b",
            "qwen2.5-1.5b": "qwen2.5-1.5b",
            "qwen2.5-3b": "qwen2.5-3b",
            "deepseek-coder-1.3b": "deepseek-coder-1.3b",
            "gemma-2b": "gemma-2b",
            "phi-2": "phi-2",
            "openelm-1.1b": "openelm-1.1b",
            "llama-3.2-1b": "llama-3.2-1b"
        ]
        
        if let modelId = simplifiedMappings[repoPath] {
            return modelId
        }
        
        // Check if it's under mlx-community
        if repoPath == "mlx-community" {
            return nil // Skip the parent directory
        }
        
        return nil
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
        
        // Check what's actually in the directories
        print("\n📂 Directory Contents:")
        
        // Check main models directory
        if let contents = try? fileManager.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil) {
            print("📁 /Models/:")
            for item in contents {
                print("   - \(item.lastPathComponent)")
            }
        }
        
        // Check MLX models directory
        let mlxModelsDir = modelsDirectory.appendingPathComponent("models/mlx-community")
        if let mlxContents = try? fileManager.contentsOfDirectory(at: mlxModelsDir, includingPropertiesForKeys: nil) {
            print("\n📁 /Models/models/mlx-community/:")
            for item in mlxContents {
                print("   - \(item.lastPathComponent)")
                
                // Check if model.safetensors exists
                let modelFile = item.appendingPathComponent("model.safetensors")
                if fileManager.fileExists(atPath: modelFile.path) {
                    if let size = try? fileManager.attributesOfItem(atPath: modelFile.path)[.size] as? Int64 {
                        print("     ✅ model.safetensors exists (\(formatBytes(size)))")
                    }
                }
            }
        }
        
        print("\n📊 Model sizes:")
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

// MARK: - FileManager Extension
extension FileManager {
    /// Check if a URL points to a directory
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}