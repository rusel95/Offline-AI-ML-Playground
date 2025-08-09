//
//  ModelFormatValidator.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation

/// Validates and detects model formats for MLX compatibility
class ModelFormatValidator {
    
    /// Supported model format types
    enum ModelFormat: String, CaseIterable {
        case mlxSafetensors = "MLX Safetensors"
        case gguf = "GGUF (Not Supported)"
        case pytorch = "PyTorch (Needs Conversion)"
        case unknown = "Unknown"
        
        var isSupported: Bool {
            switch self {
            case .mlxSafetensors:
                return true
            case .gguf, .pytorch, .unknown:
                return false
            }
        }
    }
    
    /// Model validation result
    struct ValidationResult {
        let format: ModelFormat
        let isValid: Bool
        let missingFiles: [String]
        let warnings: [String]
        let modelPath: URL?
        
        var summary: String {
            if isValid {
                return "✅ Model is valid and ready to use"
            } else {
                var message = "❌ Model validation failed"
                if !missingFiles.isEmpty {
                    message += "\nMissing files: \(missingFiles.joined(separator: ", "))"
                }
                if !warnings.isEmpty {
                    message += "\nWarnings: \(warnings.joined(separator: "; "))"
                }
                return message
            }
        }
    }
    
    /// Required files for MLX models
    private static let requiredMLXFiles = [
        "model.safetensors",
        "config.json",
        "tokenizer.json"
    ]
    
    /// Optional but recommended files
    private static let optionalMLXFiles = [
        "tokenizer_config.json",
        "special_tokens_map.json",
        "generation_config.json"
    ]
    
    /// Validate a model at the given path
    static func validate(modelPath: URL) -> ValidationResult {
        let fileManager = FileManager.default
        var missingFiles: [String] = []
        var warnings: [String] = []
        var detectedFormat = ModelFormat.unknown
        
        // Check if path exists
        guard fileManager.fileExists(atPath: modelPath.path) else {
            return ValidationResult(
                format: .unknown,
                isValid: false,
                missingFiles: ["Model path does not exist"],
                warnings: [],
                modelPath: nil
            )
        }
        
        // Detect format based on files present
        let modelFiles = (try? fileManager.contentsOfDirectory(at: modelPath, includingPropertiesForKeys: nil)) ?? []
        let fileNames = modelFiles.map { $0.lastPathComponent }
        
        // Check for MLX safetensors format
        if fileNames.contains("model.safetensors") {
            detectedFormat = .mlxSafetensors
            
            // Check required files
            for requiredFile in requiredMLXFiles {
                if !fileNames.contains(requiredFile) {
                    missingFiles.append(requiredFile)
                }
            }
            
            // Check optional files
            for optionalFile in optionalMLXFiles {
                if !fileNames.contains(optionalFile) {
                    warnings.append("Optional file '\(optionalFile)' is missing")
                }
            }
        }
        // Check for GGUF format
        else if fileNames.contains(where: { $0.hasSuffix(".gguf") }) {
            detectedFormat = .gguf
            warnings.append("GGUF format is not supported by MLX Swift")
        }
        // Check for PyTorch format
        else if fileNames.contains(where: { $0.hasSuffix(".bin") || $0 == "pytorch_model.bin" }) {
            detectedFormat = .pytorch
            warnings.append("PyTorch models need to be converted to MLX format")
        }
        
        // Validate file sizes
        if detectedFormat == .mlxSafetensors && missingFiles.isEmpty {
            if let modelFile = modelFiles.first(where: { $0.lastPathComponent == "model.safetensors" }) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: modelFile.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        if fileSize < 1024 * 1024 { // Less than 1MB
                            warnings.append("Model file seems too small (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
                        }
                    }
                } catch {
                    warnings.append("Could not check model file size")
                }
            }
        }
        
        let isValid = detectedFormat.isSupported && missingFiles.isEmpty
        
        return ValidationResult(
            format: detectedFormat,
            isValid: isValid,
            missingFiles: missingFiles,
            warnings: warnings,
            modelPath: isValid ? modelPath : nil
        )
    }
    
    /// Validate a model by ID
    static func validate(modelId: String) -> ValidationResult {
        let modelPath = ModelFileManager.shared.getMLXModelDirectory(for: modelId)
        return validate(modelPath: modelPath)
    }
    
    /// Get detailed model information
    static func getModelInfo(at path: URL) -> [String: Any] {
        var info: [String: Any] = [:]
        let fileManager = FileManager.default
        
        // Basic path info
        info["path"] = path.path
        info["exists"] = fileManager.fileExists(atPath: path.path)
        
        // Try to read config.json
        let configPath = path.appendingPathComponent("config.json")
        if let configData = try? Data(contentsOf: configPath),
           let config = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
            info["model_type"] = config["model_type"] ?? "unknown"
            info["hidden_size"] = config["hidden_size"] ?? 0
            info["num_hidden_layers"] = config["num_hidden_layers"] ?? 0
            info["vocab_size"] = config["vocab_size"] ?? 0
        }
        
        // Get file listing
        if let files = try? fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: [.fileSizeKey]) {
            var fileInfo: [[String: Any]] = []
            for file in files {
                var fileDict: [String: Any] = ["name": file.lastPathComponent]
                if let attributes = try? file.resourceValues(forKeys: [.fileSizeKey]) {
                    fileDict["size"] = attributes.fileSize ?? 0
                    fileDict["sizeFormatted"] = ByteCountFormatter.string(
                        fromByteCount: Int64(attributes.fileSize ?? 0),
                        countStyle: .file
                    )
                }
                fileInfo.append(fileDict)
            }
            info["files"] = fileInfo
        }
        
        return info
    }
    
    /// Check if a model needs migration from old format
    static func needsMigration(modelId: String) -> Bool {
        let fileManager = FileManager.default
        
        // Check if we have an old single-file download
        let oldPath = ModelFileManager.shared.getModelPath(for: modelId)
        let mlxPath = ModelFileManager.shared.getMLXModelDirectory(for: modelId)
        
        // If old file exists but MLX directory doesn't, needs migration
        return fileManager.fileExists(atPath: oldPath.path) && 
               !fileManager.fileExists(atPath: mlxPath.path)
    }
}

// MARK: - ModelFileManager Extension

extension ModelFileManager {
    /// Get the MLX model directory path
}