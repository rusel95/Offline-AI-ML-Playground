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
    private let resumeManager = DownloadResumeManager.shared
    private let networkMonitor = NetworkMonitor.shared
    
    // Download tracking
    private var lastUpdateTime: [URLSessionTask: Date] = [:]
    private var lastBytesWritten: [URLSessionTask: Int64] = [:]
    private var speedTrackers: [URLSessionTask: DownloadSpeedTracker] = [:]
    private var modelTaskMapping: [String: URLSessionTask] = [:] // Map modelId to task for resume
    
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
        
        // Monitor network changes to resume downloads
        setupNetworkMonitoring()
        
        // Clean up old resume data
        resumeManager.cleanupOldResumeData()
        
        print("✅ SharedModelManager initialized")
        print("📁 Using ModelFileManager for all file operations")
    }
    
    // MARK: - Network Monitoring
    private func setupNetworkMonitoring() {
        // Use Combine to monitor network changes
        networkMonitor.$isConnected
            .dropFirst() // Skip initial value
            .removeDuplicates()
            .sink { [weak self] isConnected in
                if isConnected {
                    Task { @MainActor in
                        await self?.resumeInterruptedDownloads()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    @MainActor
    private func resumeInterruptedDownloads() async {
        print("🌐 Network connected, checking for interrupted downloads...")
        
        let modelsWithResumeData = resumeManager.getModelsWithResumeData()
        guard !modelsWithResumeData.isEmpty else {
            print("✅ No interrupted downloads to resume")
            return
        }
        
        print("📱 Found \(modelsWithResumeData.count) interrupted downloads")
        
        for modelId in modelsWithResumeData {
            // Skip if already downloading
            if activeDownloads[modelId] != nil {
                continue
            }
            
            // Find the model
            guard let model = availableModels.first(where: { $0.id == modelId }) else {
                print("⚠️ Model not found for resume: \(modelId)")
                resumeManager.deleteResumeData(for: modelId)
                continue
            }
            
            print("🔄 Automatically resuming download for \(model.name)")
            do {
                try await downloadModel(model)
            } catch {
                print("❌ Failed to resume download for \(model.name): \(error)")
            }
        }
    }
    
    // MARK: - Directory Management
    /// Get the unified model download directory path
    func getModelDownloadDirectory() -> URL {
        return fileManager.modelsDirectory
    }
    
    // MARK: - Model Catalog Management
    private func loadCuratedModels() {
        // ==================== MLX-COMPATIBLE MODELS FOR iPHONE (2025) ====================
        // 
        // CURATED LIST: MLX-community models that work with MLX Swift
        // These models use .safetensors format and include config.json
        //
        // Model Selection Criteria:
        // ✅ MLX-community optimized models
        // ✅ .safetensors format (MLX Swift compatible)
        // ✅ 4-bit quantization for iPhone efficiency
        // ✅ 50MB-3GB size range (iPhone memory limits)
        // ✅ Tested and verified to work with MLX Swift
        //
        // ======================================================================
        
        print("📋 LOADING CURATED MLX-COMPATIBLE MODELS FOR iPHONE")
        availableModels = [
            // MARK: - Tiny Models (<100MB)
            // 1. SmolLM 135M - Ultra-lightweight
            AIModel(
                id: "smollm-135m",
                name: "SmolLM 135M Instruct",
                description: "Ultra-lightweight 75MB model from Apple's MLX community. Perfect for basic iPhone chat with minimal memory usage.",
                huggingFaceRepo: "mlx-community/SmolLM-135M-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 75000000, // ~75MB
                type: .general,
                tags: ["ultra-tiny", "apple", "mlx", "iphone-optimized", "4bit", "basic-chat", "minimal-memory"],
                isGated: false,
                provider: .apple
            ),
            
            // MARK: - Small Models (100MB-500MB)
            // 2. SmolLM 360M - Small but capable
            AIModel(
                id: "smollm-360m",
                name: "SmolLM 360M Instruct",
                description: "Small but capable 195MB model. Great balance of size and performance for iPhone.",
                huggingFaceRepo: "mlx-community/SmolLM-360M-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 195000000, // ~195MB
                type: .general,
                tags: ["small", "mlx", "360M", "iphone-optimized", "4bit", "efficient"],
                isGated: false,
                provider: .apple
            ),
            
            // 3. Qwen2.5 0.5B - Compact multilingual
            AIModel(
                id: "qwen2.5-0.5b",
                name: "Qwen2.5 0.5B Instruct",
                description: "Alibaba's ultra-compact 294MB model with multilingual support.",
                huggingFaceRepo: "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 294000000, // ~294MB
                type: .general,
                tags: ["qwen", "0.5B", "mlx", "multilingual", "tiny", "4bit"],
                isGated: false,
                provider: .other
            ),
            
            // MARK: - Medium Models (500MB-1.5GB)
            // 4. TinyLlama 1.1B - Popular lightweight model
            AIModel(
                id: "tinyllama-1.1b",
                name: "TinyLlama 1.1B Chat",
                description: "Ultra-compact 669MB Llama model optimized for iPhone. Excellent for conversational AI.",
                huggingFaceRepo: "mlx-community/TinyLlama-1.1B-Chat-v1.0-4bit",
                filename: "model.safetensors",
                sizeInBytes: 669262336, // ~669MB
                type: .llama,
                tags: ["tiny", "llama", "mlx", "chat", "iphone-optimized", "4bit"],
                isGated: false,
                provider: .meta
            ),
            
            // 5. SmolLM 1.7B - Larger SmolLM
            AIModel(
                id: "smollm-1.7b",
                name: "SmolLM 1.7B Instruct",
                description: "HuggingFace's larger SmolLM with 983MB. Better quality while staying efficient.",
                huggingFaceRepo: "mlx-community/SmolLM-1.7B-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 983000000, // ~983MB
                type: .general,
                tags: ["smollm", "1.7B", "mlx", "efficient", "4bit"],
                isGated: false,
                provider: .huggingFace
            ),
            
            // 6. Qwen2.5 1.5B - Balanced performance
            AIModel(
                id: "qwen2.5-1.5b",
                name: "Qwen2.5 1.5B Instruct",
                description: "Balanced 871MB model with good quality and multilingual support.",
                huggingFaceRepo: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 871000000, // ~871MB
                type: .general,
                tags: ["qwen", "1.5B", "mlx", "balanced", "multilingual", "4bit"],
                isGated: false,
                provider: .other
            ),
            
            // 7. OpenELM 1.1B - Apple's model
            AIModel(
                id: "openelm-1.1b",
                name: "OpenELM 1.1B Instruct",
                description: "Apple's own 665MB model, optimized for Apple Silicon and iOS devices.",
                huggingFaceRepo: "mlx-community/OpenELM-1_1B-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 665000000, // ~665MB
                type: .general,
                tags: ["apple", "openelm", "mlx", "ios-optimized", "4bit"],
                isGated: false,
                provider: .apple
            ),
            
            // MARK: - Large Models (1.5GB-3GB)
            // 8. Gemma 2B - Google's efficient model
            AIModel(
                id: "gemma-2b",
                name: "Gemma 2B Instruct",
                description: "Google's efficient 1.5GB model with excellent instruction-following.",
                huggingFaceRepo: "mlx-community/gemma-2b-it-4bit",
                filename: "model.safetensors",
                sizeInBytes: 1500000000, // ~1.5GB
                type: .general,
                tags: ["google", "gemma", "mlx", "2B", "instruction", "4bit"],
                isGated: false,
                provider: .google
            ),
            
            // 9. Phi-2 - Microsoft's compact powerhouse
            AIModel(
                id: "phi-2",
                name: "Phi-2",
                description: "Microsoft's 1.6GB compact model with strong reasoning capabilities.",
                huggingFaceRepo: "mlx-community/phi-2-4bit",
                filename: "model.safetensors",
                sizeInBytes: 1600000000, // ~1.6GB
                type: .general,
                tags: ["microsoft", "phi", "mlx", "reasoning", "4bit"],
                isGated: false,
                provider: .microsoft
            ),
            
            // 10. Qwen2.5 3B - Larger multilingual
            AIModel(
                id: "qwen2.5-3b",
                name: "Qwen2.5 3B Instruct",
                description: "Larger 1.7GB Qwen model with excellent multilingual capabilities.",
                huggingFaceRepo: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 1700000000, // ~1.7GB
                type: .general,
                tags: ["qwen", "3B", "mlx", "multilingual", "4bit"],
                isGated: false,
                provider: .other
            ),
            
            // 11. Llama 3.2 1B - Meta's latest small model
            AIModel(
                id: "llama-3.2-1b",
                name: "Llama 3.2 1B Instruct",
                description: "Meta's latest 626MB model designed for edge devices and iPhone.",
                huggingFaceRepo: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                filename: "model.safetensors",
                sizeInBytes: 626000000, // ~626MB
                type: .llama,
                tags: ["meta", "llama", "3.2", "mlx", "edge", "4bit"],
                isGated: false,
                provider: .meta
            ),
        ]
        
        print("📋 Loaded \(availableModels.count) curated MLX-COMPATIBLE models")
        print("✅ All models from mlx-community (verified to work with MLX Swift)")
        print("💾 All models in .safetensors format (MLX Swift compatible)")
        print("📱 Model sizes: 75MB - 1.7GB (optimized for iPhone)")
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
        // Check our file manager first
        if fileManager.isModelDownloaded(modelId) {
            return true
        }
        
        // For MLX models, check if the download completed
        // We'll rely on our file manager for now
        
        return false
    }
    
    func getLocalModelPath(modelId: String) -> URL? {
        guard isModelDownloaded(modelId) else { return nil }
        return fileManager.getModelPath(for: modelId)
    }
    
    // MARK: - Download Management
    /// Download a specific AI model with proper error handling and resume support
    func downloadModel(_ model: AIModel) async throws {
        // Validate model
        guard !model.id.isEmpty else {
            throw ModelError.invalidModel("Model ID cannot be empty")
        }
        
        // Check network connectivity
        guard networkMonitor.isConnected else {
            throw ModelError.networkError("No internet connection available")
        }
        
        // Check if already downloading
        if activeDownloads[model.id] != nil {
            print("⚠️ Model \(model.name) is already being downloaded")
            return
        }
        
        // For MLX models, use the MLXModelDownloader to get all required files
        if model.huggingFaceRepo.contains("mlx-community") {
            print("🔄 Using MLXModelDownloader for MLX model: \(model.name)")
            
            // Create and track the MLX downloader
            let mlxDownloader = MLXModelDownloader()
            
            // Create a placeholder download for UI tracking
            // Note: We'll use a dummy task since MLXModelDownloader manages its own downloads
            let dummyURL = URL(string: "https://example.com")!
            let dummyTask = urlSession.downloadTask(with: dummyURL)
            
            let placeholderDownload = ModelDownload(
                modelId: model.id,
                progress: 0.0,
                totalBytes: model.sizeInBytes,
                downloadedBytes: 0,
                speed: 0.0,
                task: dummyTask
            )
            activeDownloads[model.id] = placeholderDownload
            
            // Monitor MLX downloader progress
            Task { @MainActor in
                for await _ in Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().values {
                    if let download = activeDownloads[model.id] {
                        let updatedDownload = ModelDownload(
                            modelId: model.id,
                            progress: mlxDownloader.downloadProgress,
                            totalBytes: model.sizeInBytes,
                            downloadedBytes: Int64(Double(model.sizeInBytes) * mlxDownloader.downloadProgress),
                            speed: download.speed,
                            task: download.task
                        )
                        activeDownloads[model.id] = updatedDownload
                        
                        if !mlxDownloader.isDownloading {
                            break
                        }
                    }
                }
            }
            
            // Perform the download
            do {
                try await mlxDownloader.downloadMLXModel(model)
                
                // Remove from active downloads on success
                activeDownloads.removeValue(forKey: model.id)
                
                // Refresh downloaded models
                fileManager.refreshDownloadedModels()
                
                print("✅ MLX model downloaded successfully: \(model.name)")
            } catch {
                // Remove from active downloads on failure
                activeDownloads.removeValue(forKey: model.id)
                throw error
            }
            
            return
        }
        
        // For non-MLX models, use the existing download logic
        // Try to resume if we have resume data
        if let resumeData = resumeManager.loadResumeData(for: model.id) {
            print("📂 Found resume data for \(model.name), attempting to resume...")
            let task = urlSession.downloadTask(withResumeData: resumeData)
            
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
            modelTaskMapping[model.id] = task
            task.resume()
            
            print("🔄 Resumed download for \(model.name)")
            return
        }
        
        // Construct download URL for new download
        guard let url = constructModelDownloadURL(for: model) else {
            throw ModelError.networkError("Invalid download URL for model \(model.name)")
        }
        
        print("⬇️ Started downloading model: \(model.name)")
        print("🔗 Download URL: \(url)")
        
        let request = URLRequest(url: url)
        
        // Use URLSession for all downloads
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
        modelTaskMapping[model.id] = task
        task.resume()
        
        print("🚀 Download task started for \(model.name)")
    }
    
    private func constructModelDownloadURL(for model: AIModel) -> URL? {
        // ==================== MLX MODEL DOWNLOAD URL CONSTRUCTION ====================
        //
        // URL PATTERN: https://huggingface.co/{REPO}/resolve/main/{FILENAME}
        // 
        // EXAMPLES OF WORKING MLX URLS:
        // ✅ https://huggingface.co/mlx-community/SmolLM-135M-Instruct-4bit/resolve/main/model.safetensors
        // ✅ https://huggingface.co/mlx-community/TinyLlama-1.1B-Chat-v1.0-4bit/resolve/main/model.safetensors
        //
        // ================================================================
        
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(model.filename)"
        
        print("🔗 CONSTRUCTING MLX MODEL DOWNLOAD URL:")
        print("   📋 Model: \(model.name) (\(model.id))")
        print("   🏠 Repository: \(model.huggingFaceRepo)")
        print("   📄 Filename: \(model.filename)")
        print("   🌐 Final URL: \(baseURL)")
        
        return URL(string: baseURL)
    }
    
    func cancelDownload(_ modelId: String) {
        guard let download = activeDownloads[modelId] else { return }
        
        // Cancel with resume data
        download.task.cancel { resumeData in
            if let resumeData = resumeData {
                Task { @MainActor in
                    self.resumeManager.saveResumeData(resumeData, for: modelId)
                    print("💾 Saved resume data for cancelled download: \(modelId)")
                }
            }
        }
        
        activeDownloads.removeValue(forKey: modelId)
        speedTrackers.removeValue(forKey: download.task)
        modelTaskMapping.removeValue(forKey: modelId)
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
    
    /// Update model download status
    @MainActor
    func updateModelDownloadStatus(_ modelId: String, isDownloaded: Bool) async {
        // Since AIModel doesn't have isDownloaded property, we need to update the file manager directly
        if isDownloaded {
            // Create marker file to mark as downloaded
            let markerPath = fileManager.getModelPath(for: modelId)
            FileManager.default.createFile(atPath: markerPath.path, contents: nil, attributes: nil)
            print("✅ Created marker file for model: \(modelId)")
        } else {
            // Remove marker file to mark as not downloaded
            let markerPath = fileManager.getModelPath(for: modelId)
            try? FileManager.default.removeItem(at: markerPath)
            print("🗑️ Removed marker file for model: \(modelId)")
        }
        
        // Update the file manager's downloaded models list
        fileManager.refreshDownloadedModels()
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
        
        // Get the model info
        guard let model = availableModels.first(where: { $0.id == modelId }) else {
            print("❌ Could not find model info for: \(modelId)")
            try? FileManager.default.removeItem(at: backupLocation)
            return
        }
        
        // For MLX models, we need to handle the directory structure
        do {
            if model.huggingFaceRepo.contains("mlx-community") {
                print("🔄 Processing MLX model download")
                
                // For MLX models, we'll download just the model.safetensors file
                // but MLX needs it in a specific directory structure
                let modelsDir = fileManager.modelsDirectory
                let mlxDir = modelsDir.appendingPathComponent("models")
                    .appendingPathComponent("mlx-community")
                    .appendingPathComponent(model.huggingFaceRepo.components(separatedBy: "/").last ?? model.id)
                
                // Create the MLX directory structure
                try FileManager.default.createDirectory(at: mlxDir, withIntermediateDirectories: true)
                
                // Move the file to the MLX location
                let destPath = mlxDir.appendingPathComponent("model.safetensors")
                if FileManager.default.fileExists(atPath: destPath.path) {
                    try FileManager.default.removeItem(at: destPath)
                }
                try FileManager.default.moveItem(at: backupLocation, to: destPath)
                
                print("✅ MLX model saved to: \(destPath.path)")
                
                // IMPORTANT: Also save a marker file so ModelFileManager can detect it
                let markerPath = fileManager.getModelPath(for: modelId)
                try modelId.write(to: markerPath, atomically: true, encoding: .utf8)
                print("✅ Created marker file for model: \(modelId)")
            } else {
                // For non-MLX models, use the simple save
                try await fileManager.saveDownloadedFile(from: backupLocation, for: modelId)
            }
            
            // Refresh downloaded models
            fileManager.refreshDownloadedModels()
            
            // Remove from active downloads
            activeDownloads.removeValue(forKey: modelId)
            speedTrackers.removeValue(forKey: downloadTask)
            lastProgressUpdate.removeValue(forKey: downloadTask)
            modelTaskMapping.removeValue(forKey: modelId)
            
            // Clean up resume data since download completed successfully
            resumeManager.deleteResumeData(for: modelId)
            
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
                    
                    // Log progress to console for debugging
                    if let model = availableModels.first(where: { $0.id == modelId }) {
                        let percentage = Int(progress * 100)
                        let downloaded = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
                        let total = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
                        let speedStr = ByteCountFormatter.string(fromByteCount: Int64(averageSpeed), countStyle: .file)
                        print("📊 Download Progress: \(model.name) - \(percentage)% (\(downloaded)/\(total)) @ \(speedStr)/s")
                    }
                    
                    break
                }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Download failed: \(error.localizedDescription)")
            
            // Check if we can resume this download
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain,
               let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                
                Task { @MainActor in
                    // Find the model ID for this task
                    for (modelId, download) in activeDownloads {
                        if download.task == task {
                            // Save resume data
                            resumeManager.saveResumeData(resumeData, for: modelId)
                            print("💾 Saved resume data for interrupted download: \(modelId)")
                            
                            // Clean up active download
                            activeDownloads.removeValue(forKey: modelId)
                            speedTrackers.removeValue(forKey: task)
                            lastProgressUpdate.removeValue(forKey: task)
                            modelTaskMapping.removeValue(forKey: modelId)
                            
                            // If network is available, automatically retry
                            if networkMonitor.isConnected {
                                print("🔄 Network available, automatically resuming download for \(modelId)")
                                if let model = availableModels.first(where: { $0.id == modelId }) {
                                    Task {
                                        try? await downloadModel(model)
                                    }
                                }
                            } else {
                                lastError = "Download interrupted. Will resume when connection is restored."
                            }
                            break
                        }
                    }
                }
            } else {
                // Non-resumable error
                Task { @MainActor in
                    for (modelId, download) in activeDownloads {
                        if download.task == task {
                            activeDownloads.removeValue(forKey: modelId)
                            speedTrackers.removeValue(forKey: task)
                            lastProgressUpdate.removeValue(forKey: task)
                            modelTaskMapping.removeValue(forKey: modelId)
                            resumeManager.deleteResumeData(for: modelId)
                            lastError = "Download failed: \(error.localizedDescription)"
                            print("🧹 Cleaned up failed download for model: \(modelId)")
                            break
                        }
                    }
                }
            }
        }
    }
} 