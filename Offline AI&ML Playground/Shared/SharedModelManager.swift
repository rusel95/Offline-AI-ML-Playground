//
//  SharedModelManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation
import SwiftUI
import Combine

/// Errors that can occur during model operations
enum ModelError: LocalizedError {
    case invalidModel(String)
    case networkError(String)
    case fileSystemError(String)
    case authenticationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidModel(let message):
            return "Invalid Model: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .fileSystemError(let message):
            return "File System Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        }
    }
}

/// Shared singleton manager that handles both model downloads and inference
/// This ensures consistent state across all tabs and unified storage paths
@MainActor
class SharedModelManager: NSObject, ObservableObject {
    
    // MARK: - Singleton Instance
    static let shared = SharedModelManager()
    
    // MARK: - Optimized Published Properties with reduced frequency updates
    @Published var availableModels: [AIModel] = []
    @Published var activeDownloads: [String: ModelDownload] = [:]
    @Published var lastError: String?
    @Published var isLoadingAvailableModels = false
    
    // Delegate to ModelFileManager for storage tracking
    var downloadedModels: Set<String> {
        ModelFileManager.shared.downloadedModels
    }
    
    var storageUsed: Double {
        Double(ModelFileManager.shared.getTotalStorageUsed())
    }
    
    var freeStorage: Double {
        if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
            return freeSpace.doubleValue
        }
        return 0
    }
    
    // MARK: - Performance optimization properties
    private var lastStorageUpdate: Date = Date()
    private var storageUpdateThrottle: TimeInterval = 2.0 // Update storage every 2 seconds max
    private let progressUpdateThrottle: TimeInterval = 0.1 // Update progress every 100ms max
    private var lastProgressUpdate: [URLSessionTask: Date] = [:]
    
    // Batch update mechanism
    private var pendingUpdates: Set<UpdateType> = []
    private var updateTimer: Timer?
    
    private enum UpdateType: Hashable {
        case storage
        case models
        case downloads
    }
    
    // MARK: - Private Properties
    private var urlSession: URLSession!
    private let fileManager = ModelFileManager.shared
    
    // Download tracking
    private var lastUpdateTime: [URLSessionTask: Date] = [:]
    private var lastBytesWritten: [URLSessionTask: Int64] = [:]
    private var speedTrackers: [URLSessionTask: DownloadSpeedTracker] = [:]
    
    // Inference management will be handled by individual components
    
    // MARK: - Initialization
    private override init() {
        super.init()
        
        print("🚀 SharedModelManager initializing...")
        
        // Setup URLSession for downloads after super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        // Initialize after super.init()
        loadCuratedModels() // Load curated GGUF model list
        
        // Let ModelFileManager handle synchronization
        fileManager.refreshDownloadedModels()
        
        print("✅ SharedModelManager initialized")
        print("📁 Using ModelFileManager for all file operations")
    }
    
    // MARK: - Directory Management
    /// Get the unified model download directory path
    func getModelDownloadDirectory() -> URL {
        return fileManager.modelsDirectory
    }
    
    // MARK: - Model Catalog Management
    private func loadCuratedModels() {
        // ==================== PUBLIC GGUF MODELS FOR iPHONE (2025) ====================
        // 
        // CURATED LIST: Public GGUF models that don't require authentication
        // GGUF = GPT-Generated Unified Format (llama.cpp format)
        //
        // Model Selection Criteria:
        // ✅ GGUF format (Q4, Q5, Q8 quantization)
        // ✅ Public repositories (no auth required)
        // ✅ Optimized for mobile devices
        // ✅ 100MB-4GB size range (iPhone memory limits)
        // ✅ From official sources (Microsoft, Google, etc.)
        //
        // ======================================================================
        
        print("📋 LOADING CURATED GGUF CHAT MODELS FOR iPHONE")
        availableModels = [
            // MARK: - Microsoft Phi Models (PUBLIC GGUF)
            // 1. Phi-3 Mini 4K - Microsoft's public GGUF
            AIModel(
                id: "phi-3-mini-4k-gguf",
                name: "Phi-3 Mini 4K Q4",
                description: "Microsoft's efficient 3.8B model with 4-bit quantization. Excellent for iPhone.",
                huggingFaceRepo: "microsoft/Phi-3-mini-4k-instruct-gguf",
                filename: "Phi-3-mini-4k-instruct-q4.gguf",
                sizeInBytes: 2393231072, // ~2.3GB
                type: .general,
                tags: ["phi", "microsoft", "3.8B", "gguf", "chat", "public"],
                isGated: false,
                provider: .microsoft
            ),
            
            // 2. Phi-3.5 Mini Instruct GGUF
            AIModel(
                id: "phi-3.5-mini-gguf",
                name: "Phi-3.5 Mini Instruct Q4",
                description: "Latest Phi model with improved performance. 3.8B parameters, 4-bit quantized.",
                huggingFaceRepo: "microsoft/Phi-3.5-mini-instruct-gguf",
                filename: "Phi-3.5-mini-instruct-q4.gguf",
                sizeInBytes: 2300000000, // ~2.3GB
                type: .general,
                tags: ["phi", "microsoft", "3.8B", "gguf", "chat", "latest"],
                isGated: false,
                provider: .microsoft
            ),
            
            // MARK: - Google Gemma Models (PUBLIC GGUF)
            // 3. Gemma 2B IT GGUF
            AIModel(
                id: "gemma-2b-it-gguf",
                name: "Gemma 2B IT Q4_K_M",
                description: "Google's instruction-tuned 2B model. Compact and efficient.",
                huggingFaceRepo: "google/gemma-2b-it-GGUF",
                filename: "gemma-2b-it-q4_k_m.gguf",
                sizeInBytes: 1500000000, // ~1.5GB
                type: .general,
                tags: ["gemma", "google", "2B", "gguf", "chat", "public"],
                isGated: false,
                provider: .google
            ),
            
            // 4. Gemma 7B IT GGUF
            AIModel(
                id: "gemma-7b-it-gguf",
                name: "Gemma 7B IT Q4_K_M",
                description: "Google's larger instruction-tuned model. High quality conversations.",
                huggingFaceRepo: "google/gemma-7b-it-GGUF",
                filename: "gemma-7b-it-q4_k_m.gguf",
                sizeInBytes: 4500000000, // ~4.5GB
                type: .general,
                tags: ["gemma", "google", "7B", "gguf", "chat", "public"],
                isGated: false,
                provider: .google
            ),
            
            // MARK: - Qwen Models (PUBLIC GGUF)
            // 5. Qwen2.5 0.5B GGUF
            AIModel(
                id: "qwen2.5-0.5b-gguf",
                name: "Qwen2.5 0.5B Instruct Q4",
                description: "Alibaba's ultra-compact model. Only 325MB, great for quick responses.",
                huggingFaceRepo: "Qwen/Qwen2.5-0.5B-Instruct-GGUF",
                filename: "qwen2.5-0.5b-instruct-q4_k_m.gguf",
                sizeInBytes: 340000000, // ~325MB
                type: .general,
                tags: ["qwen", "0.5B", "gguf", "chat", "tiny", "public"],
                isGated: false,
                provider: .other
            ),
            
            // 6. Qwen2.5 1.5B GGUF
            AIModel(
                id: "qwen2.5-1.5b-gguf",
                name: "Qwen2.5 1.5B Instruct Q4",
                description: "Balanced Qwen model. Good quality at 964MB.",
                huggingFaceRepo: "Qwen/Qwen2.5-1.5B-Instruct-GGUF",
                filename: "qwen2.5-1.5b-instruct-q4_k_m.gguf",
                sizeInBytes: 1010000000, // ~964MB
                type: .general,
                tags: ["qwen", "1.5B", "gguf", "chat", "balanced", "public"],
                isGated: false,
                provider: .other
            ),
            
            // 7. Qwen2.5 3B GGUF
            AIModel(
                id: "qwen2.5-3b-gguf",
                name: "Qwen2.5 3B Instruct Q4",
                description: "Larger Qwen model with excellent multilingual support.",
                huggingFaceRepo: "Qwen/Qwen2.5-3B-Instruct-GGUF",
                filename: "qwen2.5-3b-instruct-q4_k_m.gguf",
                sizeInBytes: 2000000000, // ~2GB
                type: .general,
                tags: ["qwen", "3B", "gguf", "chat", "multilingual", "public"],
                isGated: false,
                provider: .other
            ),
            
            // 8. Qwen2.5 7B GGUF
            AIModel(
                id: "qwen2.5-7b-gguf",
                name: "Qwen2.5 7B Instruct Q4",
                description: "Qwen's flagship model. State-of-the-art performance.",
                huggingFaceRepo: "Qwen/Qwen2.5-7B-Instruct-GGUF",
                filename: "qwen2.5-7b-instruct-q4_k_m.gguf",
                sizeInBytes: 4400000000, // ~4.4GB
                type: .general,
                tags: ["qwen", "7B", "gguf", "chat", "flagship", "public"],
                isGated: false,
                provider: .other
            ),
            
            // MARK: - SmolLM Models (PUBLIC GGUF)
            // 9. SmolLM 135M GGUF
            AIModel(
                id: "smollm-135m-gguf",
                name: "SmolLM 135M Q8",
                description: "HuggingFace's tiniest model. Only 135MB, perfect for testing.",
                huggingFaceRepo: "HuggingFaceTB/smollm-135M-instruct-add-basics-Q8_0-GGUF",
                filename: "smollm-135m-instruct-add-basics-q8_0.gguf",
                sizeInBytes: 140000000, // ~135MB
                type: .general,
                tags: ["smollm", "135M", "gguf", "tiny", "test", "public"],
                isGated: false,
                provider: .huggingFace
            ),
            
            // 10. SmolLM 360M GGUF
            AIModel(
                id: "smollm-360m-gguf",
                name: "SmolLM 360M Q8",
                description: "Small but capable model from HuggingFace. Good for basic tasks.",
                huggingFaceRepo: "HuggingFaceTB/smollm-360M-instruct-add-basics-Q8_0-GGUF",
                filename: "smollm-360m-instruct-add-basics-q8_0.gguf",
                sizeInBytes: 387000000, // ~369MB
                type: .general,
                tags: ["smollm", "360M", "gguf", "small", "public"],
                isGated: false,
                provider: .huggingFace
            ),
            
            // 11. SmolLM 1.7B GGUF
            AIModel(
                id: "smollm-1.7b-gguf",
                name: "SmolLM 1.7B Q4",
                description: "HuggingFace's larger SmolLM. Better quality while staying efficient.",
                huggingFaceRepo: "HuggingFaceTB/smollm-1.7B-instruct-add-basics-Q4_K_M-GGUF",
                filename: "smollm-1.7b-instruct-add-basics-q4_k_m.gguf",
                sizeInBytes: 1100000000, // ~1.1GB
                type: .general,
                tags: ["smollm", "1.7B", "gguf", "efficient", "public"],
                isGated: false,
                provider: .huggingFace
            ),
        ]
        
        print("📋 Loaded \(availableModels.count) curated PUBLIC GGUF models")
        print("✅ All models from official sources (no authentication required)")
        print("💾 All models in GGUF format (llama.cpp compatible)")
        print("📱 Model sizes: 135MB - 4.5GB")
        print("🏢 Providers: \(Set(availableModels.map { $0.provider.displayName }).joined(separator: ", "))")
    }
    
    // MARK: - Model Queries
    func getDownloadedModels() -> [AIModel] {
        return availableModels.filter { fileManager.isModelDownloaded($0.id) }
    }
    
    func getAvailableLanguageModels() -> [AIModel] {
        return getDownloadedModels().filter { model in
            !model.name.lowercased().contains("mobilevit") &&
            !model.name.lowercased().contains("vision") &&
            !model.tags.contains("vision") &&
            !model.name.lowercased().contains("minilm") &&
            !model.name.lowercased().contains("embedding") &&
            !model.name.lowercased().contains("sentence") &&
            !model.tags.contains("embedding") &&
            !model.tags.contains("sentence-transformers")
        }
    }
    
    func isModelDownloaded(_ modelId: String) -> Bool {
        return fileManager.isModelDownloaded(modelId)
    }
    
    func getLocalModelPath(modelId: String) -> URL? {
        guard isModelDownloaded(modelId) else { return nil }
        return fileManager.getModelPath(for: modelId)
    }
    
    // MARK: - Download Management
    /// Download a specific AI model with proper error handling
    func downloadModel(_ model: AIModel) async throws {
        // Validate model
        guard !model.id.isEmpty else {
            throw ModelError.invalidModel("Model ID cannot be empty")
        }
        
        // Check if already downloading
        if activeDownloads[model.id] != nil {
            print("⚠️ Model \(model.name) is already being downloaded")
            return
        }
        
        // Verify internet connectivity before attempting download
        guard let url = constructModelDownloadURL(for: model) else {
            throw ModelError.networkError("Invalid download URL for model \(model.name)")
        }
        
        print("⬇️ Started downloading model: \(model.name)")
        print("🔗 Download URL: \(url)")
        
        let request = URLRequest(url: url)
        
        // CRITICAL FIX: Use the custom URLSession with delegate for progress updates
        // Remove completion handler so delegate methods are called
        let task = self.urlSession.downloadTask(with: request)
        
        // Create download tracking object
        let download = ModelDownload(
            modelId: model.id,
            progress: 0.0,
            totalBytes: 0,
            downloadedBytes: 0,
            speed: 0.0,
            task: task
        )
        
        activeDownloads[model.id] = download
        task.resume()
        
        print("🚀 Download task started for \(model.name)")
    }
    
    private func constructModelDownloadURL(for model: AIModel) -> URL? {
        // ==================== GGUF DOWNLOAD URL CONSTRUCTION ====================
        //
        // CRITICAL: Use direct file URLs for GGUF models
        //
        // URL PATTERN: https://huggingface.co/{REPO}/resolve/main/{FILENAME}
        // 
        // EXAMPLES OF WORKING GGUF URLS:
        // ✅ https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf
        // ✅ https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf
        //
        // ================================================================
        
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(model.filename)"
        
        print("🔗 CONSTRUCTING GGUF DOWNLOAD URL:")
        print("   📋 Model: \(model.name) (\(model.id))")
        print("   🏠 Repository: \(model.huggingFaceRepo)")
        print("   📄 Filename: \(model.filename)")
        print("   🌐 Final URL: \(baseURL)")
        
        return URL(string: baseURL)
    }
    
    func cancelDownload(_ modelId: String) {
        guard let download = activeDownloads[modelId] else { return }
        download.task.cancel()
        activeDownloads.removeValue(forKey: modelId)
        speedTrackers.removeValue(forKey: download.task)
        print("🛑 Cancelled download for model: \(modelId)")
    }
    
    func deleteModel(_ modelId: String) {
        do {
            try fileManager.deleteModel(modelId)
            print("🗑️ Deleted model: \(modelId)")
        } catch {
            print("❌ Error deleting model \(modelId): \(error)")
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - Storage Management
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var formattedFreeStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorage), countStyle: .file)
    }
    
    // MARK: - Download Speed Tracking
    private struct DownloadSpeedTracker {
        private var samples: [(timestamp: Date, bytes: Int64)] = []
        
        mutating func addSample(bytes: Int64) {
            let now = Date()
            samples.append((now, bytes))
            // Clean up old samples (keep only last 2 seconds)
            samples.removeAll { $0.timestamp < now.addingTimeInterval(-2) }
        }
        
        func getAverageSpeed() -> Double {
            let now = Date()
            let oneSecondAgo = now.addingTimeInterval(-1)
            
            let recentSamples = samples.filter { $0.timestamp >= oneSecondAgo }
            guard !recentSamples.isEmpty else { return 0 }
            
            let totalBytes = recentSamples.map { $0.bytes }.reduce(0, +)
            let timeSpan = now.timeIntervalSince(recentSamples.first!.timestamp)
            let effectiveSpan = max(timeSpan, 0.1)
            
            return Double(totalBytes) / effectiveSpan
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension SharedModelManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // CRITICAL: Copy the file IMMEDIATELY before URLSession deletes it
        let tempBackupURL = location.appendingPathExtension("backup")
        
        do {
            // Make a backup copy synchronously
            try FileManager.default.copyItem(at: location, to: tempBackupURL)
            print("📋 Created backup of downloaded file")
            
            // Now handle the rest asynchronously
            Task { @MainActor in
                await self.handleDownloadCompletion(downloadTask: downloadTask, backupLocation: tempBackupURL)
            }
        } catch {
            print("❌ Failed to create backup: \(error)")
            Task { @MainActor in
                await self.handleDownloadError(downloadTask: downloadTask, error: error)
            }
        }
    }
    
    @MainActor
    private func handleDownloadCompletion(downloadTask: URLSessionDownloadTask, backupLocation: URL) async {
        // Find the model being downloaded
        var targetModelId: String?
        
        for (modelId, download) in activeDownloads {
            if download.task == downloadTask {
                targetModelId = modelId
                break
            }
        }
        
        guard let modelId = targetModelId else { 
            print("⚠️ Could not find model ID for completed download")
            try? FileManager.default.removeItem(at: backupLocation)
            return 
        }
        
        print("📥 Processing download for model: \(modelId)")
        
        // Save the file using ModelFileManager
        do {
            try await fileManager.saveDownloadedFile(from: backupLocation, for: modelId)
            
            // Remove from active downloads
            activeDownloads.removeValue(forKey: modelId)
            speedTrackers.removeValue(forKey: downloadTask)
            lastProgressUpdate.removeValue(forKey: downloadTask)
            
            print("✅ Model saved successfully: \(modelId)")
        } catch {
            print("❌ Failed to save model: \(error)")
            lastError = error.localizedDescription
            
            // Clean up
            activeDownloads.removeValue(forKey: modelId)
            speedTrackers.removeValue(forKey: downloadTask)
            lastProgressUpdate.removeValue(forKey: downloadTask)
            try? FileManager.default.removeItem(at: backupLocation)
        }
    }
    
    @MainActor
    private func handleDownloadError(downloadTask: URLSessionDownloadTask, error: Error) async {
        for (modelId, download) in activeDownloads {
            if download.task == downloadTask {
                activeDownloads.removeValue(forKey: modelId)
                speedTrackers.removeValue(forKey: downloadTask)
                lastProgressUpdate.removeValue(forKey: downloadTask)
                lastError = "Download failed: \(error.localizedDescription)"
                print("🧹 Cleaned up failed download for model: \(modelId)")
                break
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
            // Throttle progress updates to prevent excessive UI refreshes
            let now = Date()
            if let lastUpdate = lastProgressUpdate[downloadTask],
               now.timeIntervalSince(lastUpdate) < progressUpdateThrottle {
                return
            }
            
            lastProgressUpdate[downloadTask] = now
            
            for (modelId, download) in activeDownloads {
                if download.task == downloadTask {
                    // Update speed tracking
                    if speedTrackers[downloadTask] == nil {
                        speedTrackers[downloadTask] = DownloadSpeedTracker()
                    }
                    speedTrackers[downloadTask]!.addSample(bytes: bytesWritten)
                    
                    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    let averageSpeed = speedTrackers[downloadTask]!.getAverageSpeed()
                    
                    let updatedDownload = ModelDownload(
                        modelId: download.modelId,
                        progress: progress,
                        totalBytes: totalBytesExpectedToWrite,
                        downloadedBytes: totalBytesWritten,
                        speed: averageSpeed,
                        task: download.task
                    )
                    
                    activeDownloads[modelId] = updatedDownload
                    break
                }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Download failed: \(error.localizedDescription)")
            
            Task { @MainActor in
                for (modelId, download) in activeDownloads {
                    if download.task == task {
                        activeDownloads.removeValue(forKey: modelId)
                        speedTrackers.removeValue(forKey: task)
                        lastProgressUpdate.removeValue(forKey: task)
                        lastError = "Download failed: \(error.localizedDescription)"
                        print("🧹 Cleaned up failed download for model: \(modelId)")
                        break
                    }
                }
            }
        }
    }
} 