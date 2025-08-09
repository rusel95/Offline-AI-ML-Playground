//
//  ModelHealthCheck.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation

/// Performs health checks on downloaded models and fixes common issues
class ModelHealthCheck {
    
    /// Health check result for a single model
    struct ModelHealth {
        let modelId: String
        let modelName: String
        let isHealthy: Bool
        let issues: [String]
        let fixes: [String]
        let format: ModelFormatValidator.ModelFormat
        let sizeOnDisk: Int64
        
        var summary: String {
            if isHealthy {
                return "✅ \(modelName): Healthy (\(ByteCountFormatter.string(fromByteCount: sizeOnDisk, countStyle: .file)))"
            } else {
                return "❌ \(modelName): \(issues.count) issue(s) found"
            }
        }
    }
    
    /// Overall health check report
    struct HealthReport {
        let totalModels: Int
        let healthyModels: Int
        let modelsWithIssues: Int
        let totalDiskUsage: Int64
        let modelHealths: [ModelHealth]
        let recommendations: [String]
        
        var summary: String {
            var report = "📊 Model Health Report\n"
            report += "========================\n"
            report += "Total Models: \(totalModels)\n"
            report += "✅ Healthy: \(healthyModels)\n"
            report += "⚠️ With Issues: \(modelsWithIssues)\n"
            report += "💾 Total Disk Usage: \(ByteCountFormatter.string(fromByteCount: totalDiskUsage, countStyle: .file))\n"
            
            if !recommendations.isEmpty {
                report += "\n📋 Recommendations:\n"
                for recommendation in recommendations {
                    report += "• \(recommendation)\n"
                }
            }
            
            return report
        }
    }
    
    /// Run a complete health check on all models
    @MainActor
    static func runHealthCheck() async -> HealthReport {
        print("🏥 Starting model health check...")
        
        let sharedManager = SharedModelManager.shared
        var modelHealths: [ModelHealth] = []
        var totalDiskUsage: Int64 = 0
        var recommendations: [String] = []
        
        // Check each model
        for model in sharedManager.availableModels {
            let health = await checkModel(model)
            modelHealths.append(health)
            totalDiskUsage += health.sizeOnDisk
        }
        
        // Generate recommendations
        let healthyCount = modelHealths.filter { $0.isHealthy }.count
        let issueCount = modelHealths.filter { !$0.isHealthy }.count
        
        if issueCount > 0 {
            recommendations.append("Run 'Fix All Issues' to resolve \(issueCount) model issue(s)")
        }
        
        if totalDiskUsage > 5_000_000_000 { // 5GB
            recommendations.append("Consider removing unused models to free up disk space")
        }
        
        // Check for duplicate models
        let duplicates = findDuplicateModels()
        if !duplicates.isEmpty {
            recommendations.append("Found \(duplicates.count) potential duplicate models")
        }
        
        return HealthReport(
            totalModels: modelHealths.count,
            healthyModels: healthyCount,
            modelsWithIssues: issueCount,
            totalDiskUsage: totalDiskUsage,
            modelHealths: modelHealths,
            recommendations: recommendations
        )
    }
    
    /// Check a single model's health
    private static func checkModel(_ model: AIModel) async -> ModelHealth {
        var issues: [String] = []
        var fixes: [String] = []
        var sizeOnDisk: Int64 = 0
        
        // Validate model format
        let validation = ModelFormatValidator.validate(modelId: model.id)
        let format = validation.format
        
        // Check if model is marked as downloaded
        let isDownloaded = await MainActor.run {
            SharedModelManager.shared.downloadedModels.contains(model.id)
        }
        
        if isDownloaded {
            // Verify files actually exist
            if !validation.isValid {
                issues.append("Model files are missing or incomplete")
                fixes.append("Re-download the model")
                
                if !validation.missingFiles.isEmpty {
                    issues.append("Missing files: \(validation.missingFiles.joined(separator: ", "))")
                }
            }
            
            // Calculate disk usage
            if let modelPath = validation.modelPath {
                sizeOnDisk = calculateDiskUsage(at: modelPath)
            }
            
            // Check for marker file
            let markerPath = ModelFileManager.shared.getModelPath(for: model.id)
            if !FileManager.default.fileExists(atPath: markerPath.path) {
                issues.append("Marker file is missing")
                fixes.append("Create marker file for proper tracking")
            }
        } else {
            // Model not downloaded but might have files
            if validation.modelPath != nil {
                issues.append("Model has files but not marked as downloaded")
                fixes.append("Update model download status")
            }
        }
        
        // Check for format-specific issues
        switch format {
        case .gguf:
            issues.append("GGUF format is not supported by MLX Swift")
            fixes.append("Download MLX-compatible version from mlx-community")
        case .pytorch:
            issues.append("PyTorch format needs conversion")
            fixes.append("Convert to MLX format or download pre-converted version")
        case .unknown:
            if isDownloaded {
                issues.append("Unknown model format")
                fixes.append("Verify model files or re-download")
            }
        case .mlxSafetensors:
            // Good format, check for warnings
            if !validation.warnings.isEmpty {
                issues.append(contentsOf: validation.warnings)
            }
        }
        
        let isHealthy = issues.isEmpty
        
        return ModelHealth(
            modelId: model.id,
            modelName: model.name,
            isHealthy: isHealthy,
            issues: issues,
            fixes: fixes,
            format: format,
            sizeOnDisk: sizeOnDisk
        )
    }
    
    /// Fix issues for a specific model
    @MainActor
    static func fixModel(_ modelId: String) async -> Bool {
        print("🔧 Attempting to fix model: \(modelId)")
        
        guard let model = SharedModelManager.shared.availableModels.first(where: { $0.id == modelId }) else {
            print("❌ Model not found: \(modelId)")
            return false
        }
        
        let health = await checkModel(model)
        
        // Apply fixes based on issues
        var fixedCount = 0
        
        // Fix missing marker file
        if health.issues.contains(where: { $0.contains("Marker file") }) {
            createMarkerFile(for: model)
            fixedCount += 1
        }
        
        // Fix download status mismatch
        if health.issues.contains(where: { $0.contains("not marked as downloaded") }) {
            await SharedModelManager.shared.updateModelDownloadStatus(modelId, isDownloaded: true)
            fixedCount += 1
        }
        
        // For other issues, recommend re-download
        if health.issues.contains(where: { $0.contains("missing or incomplete") }) {
            print("⚠️ Model needs to be re-downloaded: \(model.name)")
            // Could trigger automatic re-download here
        }
        
        print("✅ Fixed \(fixedCount) issue(s) for \(model.name)")
        return fixedCount > 0
    }
    
    /// Fix all detected issues
    @MainActor
    static func fixAllIssues() async -> (fixed: Int, total: Int) {
        let report = await runHealthCheck()
        var fixedCount = 0
        
        for health in report.modelHealths where !health.isHealthy {
            if await fixModel(health.modelId) {
                fixedCount += 1
            }
        }
        
        return (fixed: fixedCount, total: report.modelsWithIssues)
    }
    
    /// Calculate disk usage for a directory
    private static func calculateDiskUsage(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = attributes.fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    /// Find potential duplicate models
    private static func findDuplicateModels() -> [(String, String)] {
        let duplicates: [(String, String)] = []
        // This is a placeholder - implement actual duplicate detection logic
        // Future: Check for models that might be duplicated in different locations
        
        return duplicates
    }
    
    /// Create a marker file for a model
    private static func createMarkerFile(for model: AIModel) {
        let markerPath = ModelFileManager.shared.getModelPath(for: model.id)
        
        // Create empty marker file
        FileManager.default.createFile(
            atPath: markerPath.path,
            contents: nil,
            attributes: nil
        )
        
        print("✅ Created marker file for \(model.name)")
    }
    
    /// Clean up orphaned model files
    static func cleanupOrphanedFiles() async -> Int {
        print("🧹 Cleaning up orphaned model files...")
        
        let fileManager = FileManager.default
        let modelsDir = ModelFileManager.shared.modelsDirectory
        var cleanedCount = 0
        
        // Look for files that don't belong to any known model
        if let contents = try? fileManager.contentsOfDirectory(
            at: modelsDir,
            includingPropertiesForKeys: nil
        ) {
            for file in contents {
                let filename = file.lastPathComponent
                
                // Skip known directories
                if filename == "models" { continue }
                
                // Check if this file belongs to a known model
                let isKnownModel = await MainActor.run {
                    SharedModelManager.shared.availableModels.contains { model in
                        model.id == filename || 
                        model.filename == filename ||
                        filename.contains(model.id)
                    }
                }
                
                if !isKnownModel {
                    print("🗑️ Found orphaned file: \(filename)")
                    // Could delete here after user confirmation
                    cleanedCount += 1
                }
            }
        }
        
        print("✅ Found \(cleanedCount) orphaned file(s)")
        return cleanedCount
    }
}