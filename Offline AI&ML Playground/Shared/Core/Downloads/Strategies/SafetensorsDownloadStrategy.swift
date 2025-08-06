//
//  SafetensorsDownloadStrategy.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os

/// Strategy for downloading Safetensors format models
public class SafetensorsDownloadStrategy: DownloadStrategy {
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "SafetensorsDownloadStrategy")
    
    public func canHandle(model: AIModel) -> Bool {
        return model.filename.hasSuffix(".safetensors") && 
               !model.huggingFaceRepo.contains("mlx-community")
    }
    
    public func getRequiredFiles(for model: AIModel) -> [String] {
        // Safetensors models need config files too
        return [
            model.filename,
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json"
        ]
    }
    
    public func download(model: AIModel, to directory: URL) async throws -> URL {
        logger.info("Downloading Safetensors model: \(model.name)")
        
        // Create model directory
        let modelDirectory = directory.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        
        // Download all required files
        let requiredFiles = getRequiredFiles(for: model)
        
        for filename in requiredFiles {
            let downloadURL = try constructDownloadURL(for: model, filename: filename)
            let destinationURL = modelDirectory.appendingPathComponent(filename)
            
            // Skip if file already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                logger.info("File already exists, skipping: \(filename)")
                continue
            }
            
            do {
                // Download the file directly
                let (tempURL, response) = try await URLSession.shared.download(from: downloadURL)
                
                // Validate response
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw ModelError.networkError("Failed to download \(filename)")
                }
                
                // Move to destination
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                
            } catch {
                // Continue with other files even if one fails (config files might be optional)
                logger.warning("Failed to download \(filename): \(error)")
                if filename == model.filename {
                    // Main model file is required
                    throw error
                }
            }
        }
        
        logger.info("Safetensors model downloaded successfully: \(model.name)")
        return modelDirectory
    }
    
    private func constructDownloadURL(for model: AIModel, filename: String) throws -> URL {
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(filename)"
        guard let url = URL(string: baseURL) else {
            throw ModelError.networkError("Invalid download URL for \(filename)")
        }
        return url
    }
}