//
//  ModelPaths.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation

/// Centralized model path management to avoid duplication
public class ModelPaths {
    
    /// Shared instance
    public static let shared = ModelPaths()
    
    /// Base documents directory
    public let documentsDirectory: URL
    
    /// Models root directory
    public let modelsDirectory: URL
    
    /// MLX models directory
    public let mlxModelsDirectory: URL
    
    private init() {
        // Initialize base paths
        self.documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        self.modelsDirectory = documentsDirectory
            .appendingPathComponent("Models", isDirectory: true)
        
        self.mlxModelsDirectory = modelsDirectory
            .appendingPathComponent("models")
            .appendingPathComponent("mlx-community")
        
        // Ensure directories exist
        createDirectoriesIfNeeded()
    }
    
    /// Get path for a specific model
    public func getModelPath(for modelId: String) -> URL {
        return modelsDirectory.appendingPathComponent(modelId)
    }
    
    /// Get MLX model path
    public func getMLXModelPath(for repoName: String) -> URL {
        return mlxModelsDirectory.appendingPathComponent(repoName)
    }
    
    /// Get download directory for a model
    public func getDownloadDirectory(for model: AIModel) -> URL {
        if model.huggingFaceRepo.contains("mlx-community") {
            let repoName = model.huggingFaceRepo.components(separatedBy: "/").last ?? model.id
            return getMLXModelPath(for: repoName)
        } else {
            return getModelPath(for: model.id)
        }
    }
    
    /// Check if model exists at path
    public func modelExists(modelId: String) -> Bool {
        let path = getModelPath(for: modelId)
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// Get all downloaded model IDs
    public func getDownloadedModelIds() -> Set<String> {
        var modelIds = Set<String>()
        
        // Check regular models directory
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in contents {
                if url.hasDirectoryPath {
                    modelIds.insert(url.lastPathComponent)
                }
            }
        }
        
        // Check MLX models
        if let mlxContents = try? FileManager.default.contentsOfDirectory(
            at: mlxModelsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in mlxContents {
                if url.hasDirectoryPath {
                    // Map MLX directory names to model IDs
                    let mappedId = mapMLXDirectoryToModelId(url.lastPathComponent)
                    if !mappedId.isEmpty {
                        modelIds.insert(mappedId)
                    }
                }
            }
        }
        
        return modelIds
    }
    
    /// Create required directories if they don't exist
    private func createDirectoriesIfNeeded() {
        let directories = [modelsDirectory, mlxModelsDirectory]
        
        for directory in directories {
            if !FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        }
    }
    
    /// Map MLX directory name to model ID
    private func mapMLXDirectoryToModelId(_ directoryName: String) -> String {
        // This mapping should match the model catalog
        let mappings: [String: String] = [
            "SmolLM-135M-Instruct-4bit": "smollm-135m",
            "SmolLM-360M-Instruct-4bit": "smollm-360m",
            "SmolLM-1.7B-Instruct-4bit": "smollm-1.7b",
            "TinyLlama-1.1B-Chat-v1.0-4bit": "tinyllama-1.1b",
            "Qwen2.5-0.5B-Instruct-4bit": "qwen2.5-0.5b",
            "Qwen2.5-1.5B-Instruct-4bit": "qwen2.5-1.5b",
            "Qwen2.5-3B-Instruct-4bit": "qwen2.5-3b",
            "OpenELM-1_1B-Instruct-4bit": "openelm-1.1b",
            "gemma-2b-it-4bit": "gemma-2b",
            "phi-2-4bit": "phi-2",
            "Llama-3.2-1B-Instruct-4bit": "llama-3.2-1b"
        ]
        
        return mappings[directoryName] ?? ""
    }
}