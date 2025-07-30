//
//  ModelFormatDetector.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation

/// Detects and handles different AI model formats
public class ModelFormatDetector {
    
    // MARK: - Model Format Types
    public enum ModelFormat {
        case mlxSafetensors      // Apple MLX format with single safetensors file
        case multiPartSafetensors // Large models split into multiple parts
        case gguf                // Quantized GGUF format for llama.cpp
        case unknown
        
        var displayName: String {
            switch self {
            case .mlxSafetensors: return "MLX (Safetensors)"
            case .multiPartSafetensors: return "Multi-Part Model"
            case .gguf: return "GGUF (Quantized)"
            case .unknown: return "Unknown Format"
            }
        }
        
        var requiredFiles: [String] {
            switch self {
            case .mlxSafetensors:
                return ["model.safetensors", "config.json"]
            case .multiPartSafetensors:
                return ["model.safetensors.index.json", "config.json"]
            case .gguf:
                return [] // GGUF files are self-contained
            case .unknown:
                return []
            }
        }
        
        var optionalFiles: [String] {
            switch self {
            case .mlxSafetensors, .multiPartSafetensors:
                return [
                    "tokenizer.json",
                    "tokenizer_config.json",
                    "special_tokens_map.json",
                    "generation_config.json",
                    "chat_template.jinja"
                ]
            case .gguf:
                return ["config.json"]
            case .unknown:
                return []
            }
        }
    }
    
    // MARK: - Model File Info
    public struct ModelFileInfo {
        let format: ModelFormat
        let files: [ModelFile]
        let totalSize: Int64
        let isComplete: Bool
    }
    
    public struct ModelFile {
        let filename: String
        let url: URL?
        let size: Int64
        let isRequired: Bool
        let exists: Bool
    }
    
    // MARK: - Detection Methods
    
    /// Detect model format from HuggingFace repository
    public static func detectFormat(from repoId: String, modelInfo: AIModel) -> ModelFormat {
        let repoLower = repoId.lowercased()
        
        // Check for GGUF models
        if modelInfo.filename.hasSuffix(".gguf") {
            return .gguf
        }
        
        // Check for MLX models
        if repoLower.contains("mlx-community") || repoLower.contains("mlx") {
            return .mlxSafetensors
        }
        
        // Check model size - larger models are often split
        let sizeInGB = Double(modelInfo.sizeInBytes) / (1024 * 1024 * 1024)
        if sizeInGB > 5.0 && modelInfo.filename == "model.safetensors" {
            // Likely a multi-part model
            return .multiPartSafetensors
        }
        
        // Default to MLX format for safetensors
        if modelInfo.filename.hasSuffix(".safetensors") {
            return .mlxSafetensors
        }
        
        return .unknown
    }
    
    /// Analyze files in a directory to determine format
    public static func analyzeDirectory(at url: URL) -> ModelFileInfo? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            // Check for GGUF files
            if let ggufFile = contents.first(where: { $0.pathExtension == "gguf" }) {
                let size = (try? ggufFile.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return ModelFileInfo(
                    format: .gguf,
                    files: [ModelFile(
                        filename: ggufFile.lastPathComponent,
                        url: ggufFile,
                        size: Int64(size),
                        isRequired: true,
                        exists: true
                    )],
                    totalSize: Int64(size),
                    isComplete: true
                )
            }
            
            // Check for multi-part model
            let hasIndexFile = contents.contains { $0.lastPathComponent == "model.safetensors.index.json" }
            let modelParts = contents.filter { 
                $0.lastPathComponent.matches("model-\\d+-of-\\d+\\.safetensors")
            }
            
            if hasIndexFile && !modelParts.isEmpty {
                return buildModelFileInfo(for: .multiPartSafetensors, in: url, with: contents)
            }
            
            // Check for single safetensors
            let hasSafetensors = contents.contains { $0.lastPathComponent == "model.safetensors" }
            if hasSafetensors {
                return buildModelFileInfo(for: .mlxSafetensors, in: url, with: contents)
            }
            
            return nil
            
        } catch {
            print("Error analyzing directory: \(error)")
            return nil
        }
    }
    
    /// Build model file info for a specific format
    private static func buildModelFileInfo(
        for format: ModelFormat,
        in directory: URL,
        with contents: [URL]
    ) -> ModelFileInfo {
        var files: [ModelFile] = []
        var totalSize: Int64 = 0
        
        let fileManager = FileManager.default
        let contentFileNames = Set(contents.map { $0.lastPathComponent })
        
        // Add required files
        for filename in format.requiredFiles {
            let fileURL = directory.appendingPathComponent(filename)
            let exists = contentFileNames.contains(filename)
            let size: Int64
            
            if exists, let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                size = attrs[.size] as? Int64 ?? 0
            } else {
                size = 0
            }
            
            files.append(ModelFile(
                filename: filename,
                url: exists ? fileURL : nil,
                size: size,
                isRequired: true,
                exists: exists
            ))
            
            if exists {
                totalSize += size
            }
        }
        
        // Add optional files
        for filename in format.optionalFiles {
            if contentFileNames.contains(filename) {
                let fileURL = directory.appendingPathComponent(filename)
                let size: Int64
                
                if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                    size = attrs[.size] as? Int64 ?? 0
                } else {
                    size = 0
                }
                
                files.append(ModelFile(
                    filename: filename,
                    url: fileURL,
                    size: size,
                    isRequired: false,
                    exists: true
                ))
                
                totalSize += size
            }
        }
        
        // For multi-part models, add all part files
        if format == .multiPartSafetensors {
            let modelParts = contents.filter { 
                $0.lastPathComponent.matches("model-\\d+-of-\\d+\\.safetensors")
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            for partURL in modelParts {
                if let attrs = try? fileManager.attributesOfItem(atPath: partURL.path) {
                    let size = attrs[.size] as? Int64 ?? 0
                    files.append(ModelFile(
                        filename: partURL.lastPathComponent,
                        url: partURL,
                        size: size,
                        isRequired: true,
                        exists: true
                    ))
                    totalSize += size
                }
            }
        }
        
        // Check if all required files exist
        let isComplete = files.filter { $0.isRequired }.allSatisfy { $0.exists }
        
        return ModelFileInfo(
            format: format,
            files: files,
            totalSize: totalSize,
            isComplete: isComplete
        )
    }
    
    /// Get download URLs for a model based on its format
    public static func getDownloadURLs(
        for model: AIModel,
        format: ModelFormat,
        baseURL: String = "https://huggingface.co"
    ) -> [URL] {
        var urls: [URL] = []
        let repoPath = "\(baseURL)/\(model.huggingFaceRepo)/resolve/main"
        
        switch format {
        case .mlxSafetensors:
            // Add all standard files
            let files = format.requiredFiles + format.optionalFiles
            for filename in files {
                if let url = URL(string: "\(repoPath)/\(filename)") {
                    urls.append(url)
                }
            }
            
        case .multiPartSafetensors:
            // First, we'd need to fetch the index file to know how many parts
            // For now, we'll just add the index and config
            if let indexURL = URL(string: "\(repoPath)/model.safetensors.index.json") {
                urls.append(indexURL)
            }
            if let configURL = URL(string: "\(repoPath)/config.json") {
                urls.append(configURL)
            }
            // The actual parts would be determined after parsing the index file
            
        case .gguf:
            // GGUF files are typically named specifically
            if let url = URL(string: "\(repoPath)/\(model.filename)") {
                urls.append(url)
            }
            // Optionally add config
            if let configURL = URL(string: "\(repoPath)/config.json") {
                urls.append(configURL)
            }
            
        case .unknown:
            // Fallback to the model's specified filename
            if let url = URL(string: "\(repoPath)/\(model.filename)") {
                urls.append(url)
            }
        }
        
        return urls
    }
}

// MARK: - String Extension for Regex
extension String {
    func matches(_ pattern: String) -> Bool {
        return self.range(of: pattern, options: .regularExpression) != nil
    }
}