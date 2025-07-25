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
        loadCuratedModels() // Load curated model list
        
        // Synchronize models synchronously on init to avoid race conditions
        performInitialSynchronization()
        
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
        // ==================== CRITICAL ARCHITECTURAL DECISION ====================
        // 
        // PROBLEM SOLVED: MLX community repositories require authentication (HTTP 401)
        // SOLUTION: Use public repositories + MLX Swift auto-conversion
        //
        // WORKFLOW:
        // 1. Download single files from PUBLIC repositories (no auth required)
        // 2. MLX Swift's HuggingFace Hub integration auto-converts formats during loading
        // 3. ModelConfiguration uses original repository ID, not MLX community mapping
        //
        // THIS PREVENTS:
        // ❌ HTTP 401 "Invalid username or password" 
        // ❌ HTTP 404 "Entry not found"
        // ❌ "config.json not found" errors
        // ❌ 15-29 byte error page downloads
        //
        // ======================================================================
        
        print("📋 LOADING CURATED MODELS - HYBRID PUBLIC REPOSITORY APPROACH")
        availableModels = [
            // 1. TinyLlama - Public repository, MLX Swift can auto-convert
            AIModel(
                id: "tinyllama-1.1b", 
                name: "TinyLlama 1.1B Chat", 
                description: "Ultra-compact 2.2GB Llama model, publicly accessible. MLX Swift will handle conversion and optimization automatically.", 
                huggingFaceRepo: "TinyLlama/TinyLlama-1.1B-Chat-v1.0", 
                filename: "model.safetensors", 
                sizeInBytes: 2200119864, 
                type: .llama, 
                tags: ["tiny", "meta", "llama", "chat", "public", "auto-convert"], 
                isGated: false, 
                provider: .meta
            ),
            
            // 2. GPT-2 - Public repository, foundational model
            AIModel(
                id: "gpt2", 
                name: "GPT-2", 
                description: "OpenAI's foundational 548MB GPT-2 model. Publicly accessible, MLX Swift will handle optimization.", 
                huggingFaceRepo: "openai-community/gpt2", 
                filename: "model.safetensors", 
                sizeInBytes: 548118077, 
                type: .general, 
                tags: ["foundational", "openai", "public", "text-generation", "auto-convert"], 
                isGated: false, 
                provider: .openAI
            ),
            
            // 3. DistilBERT - Very small, public model for testing
            AIModel(
                id: "distilbert", 
                name: "DistilBERT Base", 
                description: "Compact 268MB BERT model for testing. Publicly accessible, good for initial model loading verification.", 
                huggingFaceRepo: "distilbert-base-uncased", 
                filename: "pytorch_model.bin", 
                sizeInBytes: 267967963, 
                type: .general, 
                tags: ["small", "bert", "public", "testing", "distilled"], 
                isGated: false, 
                provider: .other
            ),
            
            // 4. Microsoft DialoGPT - Public conversational model
            AIModel(
                id: "dialogpt-small", 
                name: "DialoGPT Small", 
                description: "Microsoft's 351MB conversational model. Publicly accessible, optimized for dialogue generation.", 
                huggingFaceRepo: "microsoft/DialoGPT-small", 
                filename: "pytorch_model.bin", 
                sizeInBytes: 351262781, 
                type: .general, 
                tags: ["microsoft", "conversation", "public", "dialogue", "small"], 
                isGated: false, 
                provider: .microsoft
            ),
            
            // 5. T5 Small - Public encoder-decoder model
            AIModel(
                id: "t5-small", 
                name: "T5 Small", 
                description: "Google's 242MB T5 model. Publicly accessible, excellent for text-to-text generation tasks.", 
                huggingFaceRepo: "t5-small", 
                filename: "pytorch_model.bin", 
                sizeInBytes: 242089512, 
                type: .general, 
                tags: ["google", "t5", "public", "text2text", "encoder-decoder"], 
                isGated: false, 
                provider: .google
            ),
        ]
        
        print("📋 Loaded \(availableModels.count) curated models with enhanced metadata")
        print("🏷️ Total tags across all models: \(Set(availableModels.flatMap { $0.tags }).count)")
        print("🏢 Providers available: \(Set(availableModels.map { $0.provider.displayName }).joined(separator: ", "))")
        print("📊 Model types: \(Set(availableModels.map { $0.type.displayName }).joined(separator: ", "))")
    }
    
    // MARK: - Model Availability
    // Models are static and pre-defined, no verification needed
    
    // MARK: - Initial Synchronization
    private func performInitialSynchronization() {
        // Perform synchronous check for downloaded models
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            storageUsed = 0
            freeStorage = 0
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDirectory, 
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            // Check which models are already downloaded
            let filesOnDisk = Set(contents.map { $0.lastPathComponent })
            let modelIdsOnDisk = Set(availableModels.compactMap { model in
                filesOnDisk.contains { filename in
                    filename.hasPrefix(model.id) && filename.contains(".")
                } ? model.id : nil
            })
            
            downloadedModels = modelIdsOnDisk
            
            // Calculate initial storage
            storageUsed = contents.reduce(0.0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Double(size)
            }
            
            // Calculate free storage
            if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                freeStorage = freeSpace.doubleValue
            }
            
            print("📊 Initial sync: \(downloadedModels.count) models found")
            print("💾 Storage used: \(formattedStorageUsed)")
            
        } catch {
            print("❌ Error in initial synchronization: \(error)")
            downloadedModels.removeAll()
            storageUsed = 0
            freeStorage = 0
        }
    }
    
    // MARK: - Optimized Model Synchronization
    func synchronizeModels() {
        // Add to pending updates for batch processing
        pendingUpdates.insert(.models)
        scheduleUpdate()
    }
    
    func synchronizeModelsImmediately() async {
        await performModelSynchronization()
    }
    
    private func performModelSynchronization() async {
        print("🔄 Synchronizing models with file system...")
        
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            return
        }
        
        // Perform synchronization on background task for better performance
        let newDownloadedModels = await Task.detached { [weak self] () -> Set<String> in
            guard let self = self else { return [] }
            
            var result: Set<String> = []
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.modelsDirectory, 
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                let filesOnDisk = Set(contents.map { $0.lastPathComponent })
                
                // CRITICAL FIX: Match model IDs with files that start with the model ID
                let availableModelsSnapshot = await self.availableModels
                let modelIdsOnDisk = Set(availableModelsSnapshot.compactMap { model in
                    // Check if any file on disk starts with this model's ID
                    let hasMatchingFile = filesOnDisk.contains { filename in
                        filename.hasPrefix(model.id) && filename.contains(".")
                    }
                    return hasMatchingFile ? model.id : nil
                })
                
                result = modelIdsOnDisk
                
            } catch {
                print("❌ Error synchronizing models: \(error)")
            }
            
            return result
        }.value
        
        // Update on main actor only if there are changes
        if self.downloadedModels != newDownloadedModels {
            let oldCount = self.downloadedModels.count
            self.downloadedModels = newDownloadedModels
            print("📊 Synchronized: \(self.downloadedModels.count) models tracked (was \(oldCount))")
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
        // ==================== STATE MANAGEMENT CRITICAL FIX ====================
        //
        // PROBLEM SOLVED: "Publishing changes from within view updates is not allowed"
        //
        // ROOT CAUSE: Direct @Published property updates during SwiftUI view update cycles
        // SOLUTION: Background file system checks + main thread state updates
        //
        // WORKFLOW:
        // 1. Fast path: Check in-memory tracking first (no file system access)
        // 2. Slow path: Background file check + deferred main thread update
        // 3. NEVER call FileManager.default.fileExists on main thread from UI context
        //
        // WHY THIS WORKS:
        // ✅ Prevents main thread blocking (no 0.35s+ hangs)
        // ✅ Prevents state update violations (DispatchQueue.main.async)  
        // ✅ Maintains UI responsiveness (immediate return for tracked models)
        //
        // ======================================================================
        
        print("🔍 CHECKING MODEL DOWNLOAD STATUS: \(modelId)")
        
        // FAST PATH: Check in-memory tracking first (immediate return)
        if downloadedModels.contains(modelId) {
            print("✅ Model \(modelId) found in tracking (fast path)")
            return true
        }
        
        print("⏳ Model \(modelId) not tracked, checking file system on background queue")
        
        // SLOW PATH: Schedule background check
        Task {
            await checkAndUpdateModelOnDisk(modelId)
        }
        
        // Return false immediately - background update will sync later
        print("⚡ Returning false immediately (background sync will update)")
        return false
    }
    
    private func checkAndUpdateModelOnDisk(_ modelId: String) async {
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        
        let fileExists = await Task.detached {
            FileManager.default.fileExists(atPath: modelPath.path)
        }.value
        
        print("📁 File system check for \(modelId): exists=\(fileExists)")
        
        if fileExists && !self.downloadedModels.contains(modelId) {
            self.downloadedModels.insert(modelId)
            print("✅ Found untracked model \(modelId), adding to tracking")
        }
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
        // ==================== DOWNLOAD URL CONSTRUCTION ====================
        //
        // CRITICAL: Use public repositories to avoid authentication (HTTP 401)
        //
        // URL PATTERN: https://huggingface.co/{PUBLIC_REPO}/resolve/main/{FILENAME}
        // 
        // EXAMPLES OF WORKING URLS:
        // ✅ https://huggingface.co/openai-community/gpt2/resolve/main/model.safetensors
        // ✅ https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0/resolve/main/model.safetensors
        // ✅ https://huggingface.co/microsoft/DialoGPT-small/resolve/main/pytorch_model.bin
        //
        // EXAMPLES OF BROKEN URLS (REQUIRE AUTH):
        // ❌ https://huggingface.co/mlx-community/gpt2-4bit/resolve/main/model.safetensors
        // ❌ https://huggingface.co/mlx-community/*/resolve/main/*
        //
        // EXPECTED RESPONSES:
        // ✅ HTTP 302 + x-linked-size header with actual file size
        // ❌ HTTP 401 "Invalid username or password"
        // ❌ HTTP 404 "Entry not found"
        //
        // ================================================================
        
        var actualFilename: String
        
        if model.filename == "*.safetensors" {
            // For MLX repositories, download the main model file first
            // MLX Swift will handle missing config.json/tokenizer.json during loading
            actualFilename = "model.safetensors"
            print("🔄 Converting wildcard filename to specific file: \(actualFilename)")
        } else {
            actualFilename = model.filename
        }
        
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(actualFilename)"
        
        print("🔗 CONSTRUCTING DOWNLOAD URL:")
        print("   📋 Model: \(model.name) (\(model.id))")
        print("   🏠 Repository: \(model.huggingFaceRepo)")
        print("   📄 Original filename: \(model.filename)")
        print("   📄 Actual filename: \(actualFilename)")
        print("   🌐 Final URL: \(baseURL)")
        print("   🔍 Expected: HTTP 302 with x-linked-size header")
        
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
    
    func calculateStorageImmediately() async {
        await performStorageCalculation()
    }
    
    private func performStorageCalculation() async {
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            self.storageUsed = 0
            self.lastStorageUpdate = Date()
            return
        }
        
        // Perform calculation on background task
        let (calculatedStorage, calculatedFreeStorage) = await Task.detached { [weak self] () -> (Double, Double) in
            guard let self = self else { return (0, 0) }
            
            var calculatedStorage: Double = 0
            var calculatedFreeStorage: Double = 0
            
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
            
            return (calculatedStorage, calculatedFreeStorage)
        }.value
        
        // Update properties
        self.storageUsed = calculatedStorage
        self.freeStorage = calculatedFreeStorage
        self.lastStorageUpdate = Date()
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
        
        Task {
            for update in updates {
                switch update {
                case .storage:
                    await performStorageCalculation()
                case .models:
                    await performModelSynchronization()
                case .downloads:
                    // Handle download updates if needed
                    break
                }
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
        // Delegate to async handler
        Task {
            await handleDownloadCompletion(downloadTask: downloadTask, location: location)
        }
    }
    
    @MainActor
    private func handleDownloadCompletion(downloadTask: URLSessionDownloadTask, location: URL) async {
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
            return 
        }
        
        // Perform file operations on background
        await moveDownloadedFile(modelId: modelId, from: location, task: downloadTask)
    }
    
    private func moveDownloadedFile(modelId: String, from location: URL, task: URLSessionDownloadTask) async {
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        // Perform file operations on background task
        let (success, fileSize) = await Task.detached {
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
                
                print("✅ Successfully saved model: \(modelId) to \(destinationURL.path)")
                return (true, fileSize)
                
            } catch {
                print("❌ Error saving model \(modelId): \(error.localizedDescription)")
                return (false, Int64(0))
            }
        }.value
        
        // Update state on main actor
        if success {
            self.downloadedModels.insert(modelId)
            self.activeDownloads.removeValue(forKey: modelId)
            self.speedTrackers.removeValue(forKey: task)
            self.lastProgressUpdate.removeValue(forKey: task)
            self.calculateStorage()
            
            print("✅ Successfully downloaded model: \(modelId)")
            print("📁 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            print("💾 Total models downloaded: \(self.downloadedModels.count)")
        } else {
            self.activeDownloads.removeValue(forKey: modelId)
            self.speedTrackers.removeValue(forKey: task)
            self.lastProgressUpdate.removeValue(forKey: task)
            self.lastError = "Failed to save \(modelId)"
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
