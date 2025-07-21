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
    
    // MARK: - Published Properties
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
    
    // MARK: - Private Properties
    private var urlSession: URLSession!
    private let documentsDirectory: URL
    private let modelsDirectory: URL
    
    // Download tracking
    private var lastUpdateTime: [URLSessionTask: Date] = [:]
    private var lastBytesWritten: [URLSessionTask: Int64] = [:]
    private var speedTrackers: [URLSessionTask: DownloadSpeedTracker] = [:]
    
    // Inference management
    private var aiInferenceManager: AIInferenceManager?
    
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
        // CRITICAL FIX: Load a small curated list of verified models instead of large static list
        // These are models that are confirmed to work with MLX and are available on HuggingFace
        availableModels = [
            // Small, reliable models for testing and mobile use
            AIModel(id: "gemma-2b", name: "Gemma 2B", description: "Google's lightweight open model", huggingFaceRepo: "google/gemma-2b-gguf", filename: "gemma-2b.gguf", sizeInBytes: 1200000000, type: .general, tags: ["language", "google"], isGated: false, provider: .google),
            
            AIModel(id: "tinyllama-1.1b", name: "TinyLlama 1.1B", description: "Meta's tiny model", huggingFaceRepo: "TinyLlama/TinyLlama-1.1B-Chat-v1.0", filename: "pytorch_model.bin", sizeInBytes: 669262336, type: .llama, tags: ["tiny", "meta"], isGated: false, provider: .meta),
            
            AIModel(id: "phi-2", name: "Phi-2", description: "Microsoft's 2.7B parameter model", huggingFaceRepo: "microsoft/phi-2", filename: "pytorch_model.bin", sizeInBytes: 1400000000, type: .general, tags: ["language", "microsoft"], isGated: false, provider: .microsoft),
            
            AIModel(id: "deepseek-coder-1.3b", name: "DeepSeek Coder 1.3B", description: "DeepSeek's small code model", huggingFaceRepo: "deepseek-ai/deepseek-coder-1.3b-instruct", filename: "pytorch_model.bin", sizeInBytes: 783741952, type: .code, tags: ["code", "deepseek"], isGated: false, provider: .deepseek),
            
            AIModel(id: "gpt2", name: "GPT-2", description: "OpenAI's original GPT-2 - reliable and fast", huggingFaceRepo: "gpt2", filename: "pytorch_model.bin", sizeInBytes: 124000000, type: .general, tags: ["language", "openai"], isGated: false, provider: .openAI),
        ]
        
        print("📋 Loaded \(availableModels.count) curated models")
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
    
    // MARK: - Model Synchronization
    func synchronizeModels() {
        print("🔄 Synchronizing models with file system...")
        
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDirectory, 
                includingPropertiesForKeys: [.fileSizeKey]
            )
            let filesOnDisk = Set(contents.map { $0.lastPathComponent })
            
            // Remove tracked models that don't exist on disk
            let modelsToRemove = downloadedModels.subtracting(filesOnDisk)
            for modelId in modelsToRemove {
                print("🗑️ Removing missing model from tracking: \(modelId)")
                downloadedModels.remove(modelId)
            }
            
            // Add untracked models found on disk
            let modelsToAdd = filesOnDisk.subtracting(downloadedModels)
            for modelId in modelsToAdd {
                let modelPath = modelsDirectory.appendingPathComponent(modelId)
                
                // Verify it's a valid model file (at least 1MB)
                if let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
                   let fileSize = attributes[.size] as? Int64,
                   fileSize > 1024 * 1024 {
                    print("✅ Adding found model to tracking: \(modelId)")
                    downloadedModels.insert(modelId)
                }
            }
            
            print("📊 Synchronized: \(downloadedModels.count) models tracked")
            
        } catch {
            print("❌ Error synchronizing models: \(error)")
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
        
        var task: URLSessionDownloadTask!
        task = URLSession.shared.downloadTask(with: url) { [weak self] localURL, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Remove from active downloads
                self.activeDownloads.removeValue(forKey: model.id)
                self.speedTrackers.removeValue(forKey: task)
                
                // Handle errors
                if let error = error {
                    print("❌ Download failed for \(model.name): \(error.localizedDescription)")
                    return
                }
                
                // Check HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    print("🌐 HTTP Status: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 403 {
                        print("🔒 Access denied: Model \(model.name) requires authorization")
                        print("💡 Please check if the model is gated or requires authentication")
                        return
                    } else if httpResponse.statusCode >= 400 {
                        print("❌ HTTP Error \(httpResponse.statusCode) for model \(model.name)")
                        return
                    }
                }
                
                // Verify we have a local file
                guard let localURL = localURL else {
                    print("❌ No local file received for \(model.name)")
                    return
                }
                
                // Move to models directory
                let modelFileName = "\(model.id).\(model.filename.components(separatedBy: ".").last ?? "bin")"
                let destinationURL = self.modelsDirectory.appendingPathComponent(modelFileName)
                
                do {
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // Move downloaded file
                    try FileManager.default.moveItem(at: localURL, to: destinationURL)
                    
                    // Verify file size
                    let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    print("📁 Model saved to: \(destinationURL.path)")
                    print("📊 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
                    
                    // Only mark as downloaded if file size is reasonable (> 1MB)
                    if fileSize > 1_000_000 {
                        self.downloadedModels.insert(model.id)
                        print("✅ Successfully downloaded model: \(model.id)")
                        
                        // Sync with file system
                        self.synchronizeModels()
                    } else {
                        print("⚠️ Downloaded file seems too small (\(fileSize) bytes), possible error")
                        try? FileManager.default.removeItem(at: destinationURL)
                    }
                    
                } catch {
                    print("❌ Failed to save model \(model.name): \(error.localizedDescription)")
                }
            }
        }
        
        // Track the download
        let download = ModelDownload(
            modelId: model.id,
            progress: 0.0,
            totalBytes: 0,
            downloadedBytes: 0,
            speed: 0.0,
            task: task
        )
        activeDownloads[model.id] = download
        speedTrackers[task] = DownloadSpeedTracker()
        
        // Start the download
        task.resume()
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
    
    // MARK: - Storage Management
    func calculateStorage() {
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            storageUsed = 0
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDirectory, 
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            storageUsed = contents.reduce(0.0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Double(size)
            }
            
            // Update free storage
            if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                self.freeStorage = freeSpace.doubleValue
            }
            
        } catch {
            storageUsed = 0
        }
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var formattedFreeStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorage), countStyle: .file)
    }
    
    // MARK: - Inference Management
    func getInferenceManager() -> AIInferenceManager {
        if aiInferenceManager == nil {
            aiInferenceManager = AIInferenceManager()
        }
        return aiInferenceManager!
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
        
        guard let modelId = targetModelId else { return }
        
        // Move file to models directory
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move downloaded file
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            // Update state on main actor
            Task { @MainActor in
                downloadedModels.insert(modelId)
                activeDownloads.removeValue(forKey: modelId)
                speedTrackers.removeValue(forKey: downloadTask)
                calculateStorage()
                print("✅ Successfully downloaded model: \(modelId)")
            }
            
        } catch {
            print("❌ Error saving model \(modelId): \(error)")
            
            Task { @MainActor in
                activeDownloads.removeValue(forKey: modelId)
                speedTrackers.removeValue(forKey: downloadTask)
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
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
            print("❌ Download failed: \(error)")
            
            Task { @MainActor in
                for (modelId, download) in activeDownloads {
                    if download.task == task {
                        activeDownloads.removeValue(forKey: modelId)
                        speedTrackers.removeValue(forKey: task)
                        break
                    }
                }
            }
        }
    }
} 