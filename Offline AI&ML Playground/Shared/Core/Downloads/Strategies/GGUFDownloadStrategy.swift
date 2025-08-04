//
//  GGUFDownloadStrategy.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os

/// Strategy for downloading GGUF format models
public class GGUFDownloadStrategy: DownloadStrategy {
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "GGUFDownloadStrategy")
    
    public func canHandle(model: AIModel) -> Bool {
        return model.filename.hasSuffix(".gguf")
    }
    
    public func getRequiredFiles(for model: AIModel) -> [String] {
        // GGUF models typically need just the main file
        return [model.filename]
    }
    
    public func download(model: AIModel, to directory: URL) async throws -> URL {
        logger.info("Downloading GGUF model: \(model.name)")
        
        // Construct download URL
        let downloadURL = try constructDownloadURL(for: model)
        
        // Create model directory
        let modelDirectory = directory.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        
        // Download the GGUF file
        let destinationURL = modelDirectory.appendingPathComponent(model.filename)
        
        // Download directly using URLSession
        let (tempURL, response) = try await URLSession.shared.download(from: downloadURL)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelError.networkError("Failed to download model")
        }
        
        // Move file to destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        logger.info("GGUF model downloaded successfully: \(model.name)")
        return modelDirectory
    }
    
    private func constructDownloadURL(for model: AIModel) throws -> URL {
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(model.filename)"
        guard let url = URL(string: baseURL) else {
            throw ModelError.networkError("Invalid download URL")
        }
        return url
    }
}