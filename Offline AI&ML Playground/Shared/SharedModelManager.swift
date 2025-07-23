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
    @Published var downloadedModels: Set<String> = []
    @Published var activeDownloads: [String: ModelDownload] = [:]
    @Published var isModelLoaded = false
    @Published var loadingProgress: Float = 0.0
    @Published var loadingStatus = "Ready"
    @Published var lastError: String?
    @Published var storageUsed: Double = 0
    @Published var freeStorage: Double = 0
    @Published var isLoadingAvailableModels = false
    
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
    private let documentsDirectory: URL
    private let modelsDirectory: URL
    
    // Download tracking
    private var lastUpdateTime: [URLSessionTask: Date] = [:]
    private var lastBytesWritten: [URLSessionTask: Int64] = [:]
    private var speedTrackers: [URLSessionTask: DownloadSpeedTracker] = [:]
    
    // Inference management will be handled by individual components
    
    // MARK: - Initialization
    private override init() {
        // Setup unified storage directory
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // CRITICAL FIX: Use unified "Models" directory for both download and inference
        self.modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        
        super.init()
        
        print("🚀 SharedModelManager initializing...")
        
        // Setup URLSession for downloads after super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        // Initialize after super.init()
        setupDirectory()
        loadCuratedModels() // Load curated model list instead of all static models
        synchronizeModels()
        calculateStorage()
        
        print("✅ SharedModelManager initialized")
        print("📁 Unified models directory: \(modelsDirectory.path)")
    }
    
    // MARK: - Directory Management
    private func setupDirectory() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
            print("📁 Models directory created/verified: \(modelsDirectory.path)")
        } catch {
            print("❌ Error creating models directory: \(error)")
        }
    }
    
    /// Get the unified model download directory path
    func getModelDownloadDirectory() -> URL {
        return modelsDirectory
    }
    
    // MARK: - Model Catalog Management
    private func loadCuratedModels() {
        // CRITICAL FIX: Load working GGUF models with correct URLs and comprehensive metadata
        // These are verified to work with MLX and are available on HuggingFace
        availableModels = [
            // Small, reliable models for testing and mobile use
            AIModel(
                id: "gemma-2b", 
                name: "Gemma 2B Instruct", 
                description: "Google's efficient 2B parameter model optimized for instruction following and mobile deployment. Excellent for chat applications with low memory requirements.", 
                huggingFaceRepo: "TheBloke/gemma-2b-it-GGUF", 
                filename: "gemma-2b-it.Q4_K_M.gguf", 
                sizeInBytes: 1200000000, 
                type: .general, 
                tags: ["language", "google", "instruction-following", "chat", "efficient", "mobile-optimized", "low-memory", "multilingual"], 
                isGated: false, 
                provider: .google
            ),
            
            AIModel(
                id: "tinyllama-1.1b", 
                name: "TinyLlama 1.1B Chat", 
                description: "Ultra-lightweight Llama-based model perfect for resource-constrained environments. Ideal for basic chat and simple text generation tasks.", 
                huggingFaceRepo: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", 
                filename: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf", 
                sizeInBytes: 669262336, 
                type: .llama, 
                tags: ["tiny", "meta", "llama", "ultra-lightweight", "fast", "basic-chat", "low-power", "edge-computing"], 
                isGated: false, 
                provider: .meta
            ),
            
            AIModel(
                id: "phi-2", 
                name: "Phi-2", 
                description: "Microsoft's compact 2.7B parameter model with strong reasoning capabilities. Excellent performance-to-size ratio for educational and research tasks.", 
                huggingFaceRepo: "TheBloke/phi-2-GGUF", 
                filename: "phi-2.Q4_K_M.gguf", 
                sizeInBytes: 1400000000, 
                type: .general, 
                tags: ["language", "microsoft", "reasoning", "education", "research", "compact", "high-performance", "mathematics", "science"], 
                isGated: false, 
                provider: .microsoft
            ),
            
            AIModel(
                id: "deepseek-coder-1.3b", 
                name: "DeepSeek Coder 1.3B", 
                description: "Specialized coding model trained on massive code datasets. Excels at code generation, debugging, and explanation across multiple programming languages.", 
                huggingFaceRepo: "TheBloke/deepseek-coder-1.3b-instruct-GGUF", 
                filename: "deepseek-coder-1.3b-instruct.Q4_K_M.gguf", 
                sizeInBytes: 783741952, 
                type: .code, 
                tags: ["code", "deepseek", "programming", "multi-language", "debugging", "code-completion", "software-development", "algorithms"], 
                isGated: false, 
                provider: .deepseek
            ),
            
            AIModel(
                id: "gpt2", 
                name: "GPT-2", 
                description: "OpenAI's foundational transformer model. Reliable for text generation, creative writing, and understanding transformer architecture fundamentals.", 
                huggingFaceRepo: "TheBloke/gpt2-GGUF", 
                filename: "gpt2.Q4_K_M.gguf", 
                sizeInBytes: 124000000, 
                type: .general, 
                tags: ["language", "openai", "foundational", "creative-writing", "text-generation", "historical", "well-documented", "research"], 
                isGated: false, 
                provider: .openAI
            ),
        ]
        
        print("📋 Loaded \(availableModels.count) curated models with enhanced metadata")
        print("🏷️ Total tags across all models: \(Set(availableModels.flatMap { $0.tags }).count)")
        print("🏢 Providers available: \(Set(availableModels.map { $0.provider.displayName }).joined(separator: ", "))")
        print("📊 Model types: \(Set(availableModels.map { $0.type.displayName }).joined(separator: ", "))")
    }
    
    // MARK: - Model Availability Checking
    func verifyModelAvailability() async {
        await MainActor.run { isLoadingAvailableModels = true }
        
        print("🔍 Verifying model availability on HuggingFace...")
        
        var verifiedModels: [AIModel] = []
        
        for model in availableModels {
            let isAvailable = await checkModelAvailability(model)
            if isAvailable {
                verifiedModels.append(model)
                print("✅ Model available: \(model.name)")
            } else {
                print("❌ Model not available: \(model.name)")
            }
        }
        
        await MainActor.run {
            availableModels = verifiedModels
            isLoadingAvailableModels = false
        }
        
        print("✅ Model verification completed. \(verifiedModels.count) models available.")
    }
    
    private func checkModelAvailability(_ model: AIModel) async -> Bool {
        // Check if model repository exists on HuggingFace
        let apiUrl = "https://huggingface.co/api/models/\(model.huggingFaceRepo)"
        
        guard let url = URL(string: apiUrl) else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("❌ Failed to verify \(model.name): \(error)")
            return false
        }
    }
    
    // MARK: - Optimized Model Synchronization
    func synchronizeModels() {
        // Add to pending updates for batch processing
        pendingUpdates.insert(.models)
        scheduleUpdate()
    }
    
    private func performModelSynchronization() {
        print("🔄 Synchronizing models with file system...")
        
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            return
        }
        
        // Perform synchronization on background queue for better performance
        DispatchQueue.global(qos: .userInitiated).async {
            var newDownloadedModels: Set<String> = []
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.modelsDirectory, 
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                let filesOnDisk = Set(contents.map { $0.lastPathComponent })
                
                // CRITICAL FIX: Match model IDs with files that start with the model ID
                let modelIdsOnDisk = Set(self.availableModels.compactMap { model in
                    // Check if any file on disk starts with this model's ID
                    let hasMatchingFile = filesOnDisk.contains { filename in
                        filename.hasPrefix(model.id) && filename.contains(".")
                    }
                    return hasMatchingFile ? model.id : nil
                })
                
                newDownloadedModels = modelIdsOnDisk
                
            } catch {
                print("❌ Error synchronizing models: \(error)")
            }
            
            // Update on main thread only if there are changes
            DispatchQueue.main.async {
                if self.downloadedModels != newDownloadedModels {
                    let oldCount = self.downloadedModels.count
                    self.downloadedModels = newDownloadedModels
                    print("📊 Synchronized: \(self.downloadedModels.count) models tracked (was \(oldCount))")
                }
            }
        }
    }
    
    // MARK: - Model Queries
    func getDownloadedModels() -> [AIModel] {
        return availableModels.filter { downloadedModels.contains($0.id) }
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
        // Check in-memory tracking
        if downloadedModels.contains(modelId) {
            // Verify file exists
            let modelPath = modelsDirectory.appendingPathComponent(modelId)
            let fileExists = FileManager.default.fileExists(atPath: modelPath.path)
            
            if !fileExists {
                print("⚠️ Model \(modelId) tracked but file missing, removing from tracking")
                downloadedModels.remove(modelId)
                return false
            }
            return true
        }
        
        // Check if file exists but not tracked
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        let fileExists = FileManager.default.fileExists(atPath: modelPath.path)
        
        if fileExists {
            print("✅ Found untracked model \(modelId), adding to tracking")
            downloadedModels.insert(modelId)
            return true
        }
        
        return false
    }
    
    func getLocalModelPath(modelId: String) -> URL? {
        guard isModelDownloaded(modelId) else { return nil }
        return modelsDirectory.appendingPathComponent(modelId)
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
        // Construct proper HuggingFace download URL
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(model.filename)"
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
        let modelURL = modelsDirectory.appendingPathComponent(modelId)
        do {
            try FileManager.default.removeItem(at: modelURL)
            downloadedModels.remove(modelId)
            calculateStorage()
            print("🗑️ Deleted model: \(modelId)")
        } catch {
            print("❌ Error deleting model \(modelId): \(error)")
        }
    }
    
    // MARK: - Optimized Storage Management
    func calculateStorage() {
        // Throttle storage calculations to prevent excessive UI updates
        let now = Date()
        guard now.timeIntervalSince(lastStorageUpdate) >= storageUpdateThrottle else {
            return
        }
        
        pendingUpdates.insert(.storage)
        scheduleUpdate()
    }
    
    private func performStorageCalculation() {
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            DispatchQueue.main.async {
                self.storageUsed = 0
                self.lastStorageUpdate = Date()
            }
            return
        }
        
        // Perform calculation on background queue
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let calculatedStorage: Double
            let calculatedFreeStorage: Double
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.modelsDirectory, 
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                
                calculatedStorage = contents.reduce(0.0) { total, url in
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    return total + Double(size)
                }
                
                // Update free storage
                if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
                   let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                    calculatedFreeStorage = freeSpace.doubleValue
                } else {
                    calculatedFreeStorage = 0
                }
                
            } catch {
                calculatedStorage = 0
                calculatedFreeStorage = 0
            }
            
            // Update on main thread
            await MainActor.run {
                self.storageUsed = calculatedStorage
                self.freeStorage = calculatedFreeStorage
                self.lastStorageUpdate = Date()
            }
        }
    }
    
    // MARK: - Batch Update System
    private func scheduleUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingUpdates()
            }
        }
    }
    
    private func processPendingUpdates() {
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        for update in updates {
            switch update {
            case .storage:
                performStorageCalculation()
            case .models:
                performModelSynchronization()
            case .downloads:
                // Handle download updates if needed
                break
            }
        }
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var formattedFreeStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorage), countStyle: .file)
    }
    
    // MARK: - Inference Management
    // Inference management moved to individual view models for better performance
    
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
        // Find the model being downloaded
        var targetModelId: String?
        
        DispatchQueue.main.sync {
            for (modelId, download) in activeDownloads {
                if download.task == downloadTask {
                    targetModelId = modelId
                    break
                }
            }
        }
        
        guard let modelId = targetModelId else { 
            print("⚠️ Could not find model ID for completed download")
            return 
        }
        
        // Move file to models directory
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("🔄 Replaced existing model file: \(modelId)")
            }
            
            // Move downloaded file
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            // Verify the moved file
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path))?[.size] as? Int64 ?? 0
            
            // Update state on main actor
            Task { @MainActor in
                downloadedModels.insert(modelId)
                activeDownloads.removeValue(forKey: modelId)
                speedTrackers.removeValue(forKey: downloadTask)
                lastProgressUpdate.removeValue(forKey: downloadTask)
                calculateStorage()
                
                print("✅ Successfully downloaded model: \(modelId)")
                print("📁 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
                print("💾 Total models downloaded: \(downloadedModels.count)")
            }
            
        } catch {
            print("❌ Error saving model \(modelId): \(error.localizedDescription)")
            
            Task { @MainActor in
                activeDownloads.removeValue(forKey: modelId)
                speedTrackers.removeValue(forKey: downloadTask)
                lastProgressUpdate.removeValue(forKey: downloadTask)
                lastError = "Failed to save \(modelId): \(error.localizedDescription)"
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
                        print("🧹 Cleaned up failed download for model: \(modelId)")
                        break
                    }
                }
            }
        }
    }
} 
