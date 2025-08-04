//
//  MLXDownloadStrategy.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os

/// Strategy for downloading MLX community models
public class MLXDownloadStrategy: DownloadStrategy {
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "MLXDownloadStrategy")
    
    public func canHandle(model: AIModel) -> Bool {
        return model.huggingFaceRepo.contains("mlx-community")
    }
    
    public func getRequiredFiles(for model: AIModel) -> [String] {
        // MLX models need specific files
        return [
            "model.safetensors",
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json",
            "model.safetensors.index.json" // For multi-part models
        ]
    }
    
    public func download(model: AIModel, to directory: URL) async throws -> URL {
        logger.info("Downloading MLX model: \(model.name)")
        
        // MLX models need a specific directory structure
        let mlxDirectory = directory
            .appendingPathComponent("models")
            .appendingPathComponent("mlx-community")
            .appendingPathComponent(model.huggingFaceRepo.components(separatedBy: "/").last ?? model.id)
        
        try FileManager.default.createDirectory(at: mlxDirectory, withIntermediateDirectories: true)
        
        // Download required files for MLX models
        let requiredFiles = getRequiredFiles(for: model)
        
        for filename in requiredFiles {
            let fileURL = URL(string: "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(filename)")!
            let destinationURL = mlxDirectory.appendingPathComponent(filename)
            
            // Skip if file already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                continue
            }
            
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: fileURL)
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            } catch {
                // Some files might be optional, continue
                logger.info("Optional file not found: \(filename)")
            }
        }
        
        logger.info("MLX model downloaded successfully: \(model.name)")
        return mlxDirectory
    }
}