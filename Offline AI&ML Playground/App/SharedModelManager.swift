//
//  SharedModelManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation
import SwiftUI
import Combine

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
        loadStaticModels()
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
    private func loadStaticModels() {
        availableModels = [
            // Microsoft Models
            AIModel(id: "phi-3-mini-4k", name: "Phi-3 Mini 4K", description: "Microsoft's efficient SLM with 4K context", huggingFaceRepo: "microsoft/Phi-3-mini-4k-instruct-gguf", filename: "Phi-3-mini-4k-instruct-q4_0.gguf", sizeInBytes: 2400000000, type: .general, tags: ["slm", "microsoft"], isGated: false, provider: .microsoft),
            
            AIModel(id: "phi-3-mini-128k", name: "Phi-3 Mini 128K", description: "Microsoft's SLM with extended 128K context", huggingFaceRepo: "microsoft/Phi-3-mini-128k-instruct-gguf", filename: "Phi-3-mini-128k-instruct-q4_0.gguf", sizeInBytes: 2400000000, type: .general, tags: ["slm", "microsoft", "long-context"], isGated: false, provider: .microsoft),
            
            AIModel(id: "phi-2", name: "Phi-2", description: "Microsoft's 2.7B parameter model", huggingFaceRepo: "TheBloke/phi-2-GGUF", filename: "phi-2.Q4_K_M.gguf", sizeInBytes: 1400000000, type: .general, tags: ["language", "microsoft"], isGated: false, provider: .microsoft),
            
            // Meta Models
            AIModel(id: "tinyllama-1.1b", name: "TinyLlama 1.1B", description: "Meta's tiny model", huggingFaceRepo: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF", filename: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf", sizeInBytes: 669262336, type: .llama, tags: ["tiny", "meta"], isGated: false, provider: .meta),
            
            AIModel(id: "llama-2-7b-chat", name: "Llama 2 7B Chat", description: "Meta's 7B parameter chat model", huggingFaceRepo: "TheBloke/Llama-2-7B-Chat-GGUF", filename: "llama-2-7b-chat.Q4_K_M.gguf", sizeInBytes: 3800000000, type: .llama, tags: ["chat", "meta"], isGated: false, provider: .meta),
            
            // Google Models
            AIModel(id: "gemma-2b", name: "Gemma 2B", description: "Google's lightweight open model", huggingFaceRepo: "google/gemma-2b-gguf", filename: "gemma-2b.gguf", sizeInBytes: 1200000000, type: .general, tags: ["language", "google"], isGated: false, provider: .google),
            
            // DeepSeek Models
            AIModel(id: "deepseek-coder-1.3b", name: "DeepSeek Coder 1.3B", description: "DeepSeek's small code model", huggingFaceRepo: "TheBloke/deepseek-coder-1.3b-instruct-GGUF", filename: "deepseek-coder-1.3b-instruct.Q4_K_M.gguf", sizeInBytes: 783741952, type: .code, tags: ["code", "deepseek"], isGated: false, provider: .deepseek),
            
            // Apple Models - Lightweight and Perfect for Testing!
            AIModel(id: "mobilevit-small", name: "MobileViT Small", description: "Apple's efficient vision transformer optimized for mobile", huggingFaceRepo: "apple/mobilevit-small", filename: "pytorch_model.bin", sizeInBytes: 24000000, type: .general, tags: ["vision", "mobile", "apple", "efficient"], isGated: false, provider: .apple),
            
            AIModel(id: "mobilevit-x-small", name: "MobileViT XS", description: "Apple's ultra-lightweight vision model", huggingFaceRepo: "apple/mobilevit-x-small", filename: "pytorch_model.bin", sizeInBytes: 12000000, type: .general, tags: ["vision", "mobile", "apple", "tiny"], isGated: false, provider: .apple),
            
            // HuggingFace Lightweight Models
            AIModel(id: "all-minilm-l6-v2", name: "All-MiniLM-L6-v2", description: "Lightweight sentence embeddings perfect for mobile", huggingFaceRepo: "sentence-transformers/all-MiniLM-L6-v2", filename: "pytorch_model.bin", sizeInBytes: 90917138, type: .general, tags: ["embeddings", "mobile", "lightweight"], isGated: false, provider: .huggingFace),
            
            // Mistral Models
            AIModel(id: "mistral-7b-instruct", name: "Mistral 7B Instruct", description: "Mistral AI's instruction model", huggingFaceRepo: "TheBloke/Mistral-7B-Instruct-v0.1-GGUF", filename: "mistral-7b-instruct-v0.1.Q4_K_M.gguf", sizeInBytes: 3800000000, type: .mistral, tags: ["instruct", "mistral"], isGated: false, provider: .mistral)
        ]
        
        print("📋 Loaded \(availableModels.count) available models")
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
    func downloadModel(_ model: AIModel) {
        guard !activeDownloads.contains(where: { $0.key == model.id }) else {
            print("⚠️ Model \(model.id) already downloading")
            return
        }
        guard !isModelDownloaded(model.id) else {
            print("⚠️ Model \(model.id) already downloaded")
            return
        }
        
        let url = constructHuggingFaceURL(repo: model.huggingFaceRepo, filename: model.filename)
        
        var request = URLRequest(url: url)
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("Offline-AI-ML-Playground/1.0", forHTTPHeaderField: "User-Agent")
        
        let task = urlSession.downloadTask(with: request)
        
        let download = ModelDownload(
            modelId: model.id,
            progress: 0.0,
            totalBytes: model.sizeInBytes,
            downloadedBytes: 0,
            speed: 0,
            task: task
        )
        
        activeDownloads[model.id] = download
        task.resume()
        
        print("⬇️ Started downloading model: \(model.name)")
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
    
    // MARK: - Helper Methods
    private func constructHuggingFaceURL(repo: String, filename: String) -> URL {
        let baseURL = "https://huggingface.co/\(repo)/resolve/main/\(filename)"
        return URL(string: baseURL)!
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