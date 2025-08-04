//
//  MultiPartDownloadStrategy.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os

/// Strategy for downloading multi-part models
public class MultiPartDownloadStrategy: DownloadStrategy {
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "MultiPartDownloadStrategy")
    
    public func canHandle(model: AIModel) -> Bool {
        // Check if model has multiple parts (usually indicated by size or specific naming)
        return model.filename.contains("part") || 
               model.filename.contains("shard") ||
               model.sizeInBytes > 5_000_000_000 // Models > 5GB often split
    }
    
    public func getRequiredFiles(for model: AIModel) -> [String] {
        // Multi-part models need index file and all parts
        var files = [
            "model.safetensors.index.json",
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json"
        ]
        
        // Add part files (this would be determined from index.json in real implementation)
        // For now, assume standard naming
        for i in 1...4 {
            files.append("model-\(String(format: "%05d", i))-of-00004.safetensors")
        }
        
        return files
    }
    
    public func download(model: AIModel, to directory: URL) async throws -> URL {
        logger.info("Downloading multi-part model: \(model.name)")
        
        // Create model directory
        let modelDirectory = directory.appendingPathComponent(model.id)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        
        // First, download the index file to determine actual parts
        let indexURL = try constructDownloadURL(for: model, filename: "model.safetensors.index.json")
        let indexPath = modelDirectory.appendingPathComponent("model.safetensors.index.json")
        
        // Download index file
        try await downloadFile(from: indexURL, to: indexPath, modelId: "\(model.id)_index")
        
        // Parse index to get actual part files
        let partFiles = try parseIndexFile(at: indexPath)
        
        // Download all parts in parallel (with concurrency limit)
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Limit concurrent downloads to 3
            let semaphore = AsyncSemaphore(value: 3)
            
            for partFile in partFiles {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task {
                            await semaphore.signal()
                        }
                    }
                    
                    let partURL = try self.constructDownloadURL(for: model, filename: partFile)
                    let partPath = modelDirectory.appendingPathComponent(partFile)
                    
                    if !FileManager.default.fileExists(atPath: partPath.path) {
                        try await self.downloadFile(from: partURL, to: partPath, modelId: "\(model.id)_\(partFile)")
                    }
                }
            }
            
            // Download config files
            let configFiles = ["config.json", "tokenizer.json", "tokenizer_config.json"]
            for configFile in configFiles {
                group.addTask {
                    await semaphore.wait()
                    defer { 
                        Task {
                            await semaphore.signal()
                        }
                    }
                    
                    let configURL = try self.constructDownloadURL(for: model, filename: configFile)
                    let configPath = modelDirectory.appendingPathComponent(configFile)
                    
                    if !FileManager.default.fileExists(atPath: configPath.path) {
                        do {
                            try await self.downloadFile(from: configURL, to: configPath, modelId: "\(model.id)_\(configFile)")
                        } catch {
                            self.logger.warning("Failed to download \(configFile): \(error)")
                        }
                    }
                }
            }
            
            try await group.waitForAll()
        }
        
        logger.info("Multi-part model downloaded successfully: \(model.name)")
        return modelDirectory
    }
    
    private func constructDownloadURL(for model: AIModel, filename: String) throws -> URL {
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(filename)"
        guard let url = URL(string: baseURL) else {
            throw ModelError.networkError("Invalid download URL for \(filename)")
        }
        return url
    }
    
    private func parseIndexFile(at url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let weightMap = json?["weight_map"] as? [String: String] ?? [:]
        
        // Get unique file names from weight map
        let uniqueFiles = Set(weightMap.values)
        return Array(uniqueFiles)
    }
    
    private func downloadFile(from url: URL, to destinationURL: URL, modelId: String) async throws {
        // Create a download request
        let request = URLRequest(url: url)
        
        // Download the file
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModelError.downloadError("Failed to download file from \(url)")
        }
        
        // Move to destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        logger.debug("Downloaded file to: \(destinationURL.lastPathComponent)")
    }
}

/// Simple async semaphore for limiting concurrent operations
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}