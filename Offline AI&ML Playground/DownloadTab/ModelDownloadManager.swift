//
//  ModelDownloadManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import Foundation

// MARK: - Download Manager
@MainActor
class ModelDownloadManager: NSObject, ObservableObject {
    @Published var availableModels: [AIModel] = []
    @Published var downloadedModels: Set<String> = []
    @Published var activeDownloads: [String: ModelDownload] = [:]
    @Published var storageUsed: Double = 0
    @Published var freeStorage: Double = 0 // Will be set dynamically
    
    private var urlSession: URLSession!
    private let documentsDirectory: URL
    private let modelsDirectory: URL
    
    override init() {
        // Setup directories
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        
        super.init()
        
        // Create URLSession with delegate
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        // Create models directory
        createModelsDirectoryIfNeeded()
        
        // Synchronize downloaded models with files on disk
        synchronizeDownloadedModels()
        
        // Calculate initial storage
        calculateStorageUsed()
        updateTotalStorage()
        
        print("📱 ModelDownloadManager initialized")
        print("📁 Models directory: \(modelsDirectory.path)")
        print("📊 Found \(downloadedModels.count) downloaded models")
    }
    
    // MARK: - Public Methods
    
    func getDownloadedModels() -> [AIModel] {
        return availableModels.filter { downloadedModels.contains($0.id) }
    }
    
    func refreshAvailableModels() {
        // iPhone-compatible, lightweight models for mobile deployment
        availableModels = [
            // META MODELS (4+ models)
            AIModel(
                id: "tinyllama-1.1b-chat-q4-k-m",
                name: "TinyLlama 1.1B Chat",
                description: "Ultra-lightweight chat model optimized for mobile devices",
                huggingFaceRepo: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
                filename: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
                sizeInBytes: 669_262_336, // ~638MB
                type: .llama,
                tags: ["chat", "mobile", "tiny", "1b"],
                isGated: false,
                provider: .meta
            ),
            
            AIModel(
                id: "llama-2-7b-chat-q4-k-m",
                name: "Llama 2 7B Chat",
                description: "Meta's popular 7B parameter chat model",
                huggingFaceRepo: "TheBloke/Llama-2-7B-Chat-GGUF",
                filename: "llama-2-7b-chat.Q4_K_M.gguf",
                sizeInBytes: 3_800_000_000, // ~3.8GB
                type: .llama,
                tags: ["chat", "llama2", "7b", "meta"],
                isGated: false,
                provider: .meta
            ),
            
            AIModel(
                id: "llama-3-8b-instruct-q4-k-m",
                name: "Llama 3 8B Instruct",
                description: "Latest Llama 3 instruction-tuned model",
                huggingFaceRepo: "TheBloke/Llama-3-8B-Instruct-GGUF",
                filename: "llama-3-8b-instruct.Q4_K_M.gguf",
                sizeInBytes: 4_200_000_000, // ~4.2GB
                type: .llama,
                tags: ["instruct", "llama3", "8b", "meta"],
                isGated: false,
                provider: .meta
            ),
            
            AIModel(
                id: "codellama-7b-instruct-q4-k-m",
                name: "Code Llama 7B Instruct",
                description: "Meta's specialized code generation and understanding model",
                huggingFaceRepo: "TheBloke/CodeLlama-7B-Instruct-GGUF",
                filename: "codellama-7b-instruct.Q4_K_M.gguf",
                sizeInBytes: 4_081_004_544, // ~3.8GB
                type: .code,
                tags: ["codellama", "meta", "programming", "7b"],
                isGated: false,
                provider: .meta
            ),
            
            // GOOGLE MODELS (including Guan/Quen)
            AIModel(
                id: "distilbert-base-uncased",
                name: "DistilBERT Mobile",
                description: "Lightweight BERT model perfect for mobile NLP tasks",
                huggingFaceRepo: "distilbert-base-uncased",
                filename: "pytorch_model.bin",
                sizeInBytes: 267_967_963, // ~255MB
                type: .general,
                tags: ["nlp", "mobile", "bert", "distilled"],
                isGated: false,
                provider: .google
            ),
            
            AIModel(
                id: "guanaco-7b-q4-k-m",
                name: "Guanaco 7B",
                description: "Google's high-performance instruction-following model",
                huggingFaceRepo: "TheBloke/guanaco-7B-GGUF",
                filename: "guanaco-7B.Q4_K_M.gguf",
                sizeInBytes: 3_800_000_000, // ~3.8GB
                type: .general,
                tags: ["guanaco", "instruct", "7b", "google"],
                isGated: false,
                provider: .google
            ),
            
            AIModel(
                id: "quen-7b-q4-k-m",
                name: "Quen 7B",
                description: "Google's efficient language model for mobile deployment",
                huggingFaceRepo: "TheBloke/quen-7B-GGUF",
                filename: "quen-7B.Q4_K_M.gguf",
                sizeInBytes: 3_800_000_000, // ~3.8GB
                type: .general,
                tags: ["quen", "mobile", "7b", "google"],
                isGated: false,
                provider: .google
            ),
            
            AIModel(
                id: "gemma-2b-it-q4-k-m",
                name: "Gemma 2B Instruct",
                description: "Google's lightweight instruction-tuned model",
                huggingFaceRepo: "TheBloke/gemma-2b-it-GGUF",
                filename: "gemma-2b-it.Q4_K_M.gguf",
                sizeInBytes: 1_200_000_000, // ~1.2GB
                type: .general,
                tags: ["gemma", "instruct", "2b", "google"],
                isGated: false,
                provider: .google
            ),
            
            // MISTRAL MODELS
            AIModel(
                id: "mistral-7b-instruct-v0.1-q4-k-m",
                name: "Mistral 7B Instruct Q4",
                description: "High-quality instruction-following model from Mistral AI",
                huggingFaceRepo: "TheBloke/Mistral-7B-Instruct-v0.1-GGUF",
                filename: "mistral-7b-instruct-v0.1.Q4_K_M.gguf",
                sizeInBytes: 4_368_439_296, // ~4.07GB
                type: .mistral,
                tags: ["mistral", "instruct", "chat", "7b"],
                isGated: false,
                provider: .mistral
            ),
            
            AIModel(
                id: "mistral-7b-openorca-q4-k-m",
                name: "Mistral 7B OpenOrca Q4",
                description: "Mistral model fine-tuned on OpenOrca dataset",
                huggingFaceRepo: "TheBloke/Mistral-7B-OpenOrca-GGUF",
                filename: "mistral-7b-openorca.Q4_K_M.gguf",
                sizeInBytes: 4_368_439_296, // ~4.07GB
                type: .mistral,
                tags: ["mistral", "openorca", "fine-tuned", "7b"],
                isGated: false,
                provider: .mistral
            ),
            
            AIModel(
                id: "mistral-7b-v0.1-q4-k-m",
                name: "Mistral 7B v0.1",
                description: "Base Mistral 7B model for general tasks",
                huggingFaceRepo: "TheBloke/Mistral-7B-v0.1-GGUF",
                filename: "mistral-7b-v0.1.Q4_K_M.gguf",
                sizeInBytes: 4_368_439_296, // ~4.07GB
                type: .mistral,
                tags: ["mistral", "base", "7b"],
                isGated: false,
                provider: .mistral
            ),
            
            // DEEPSEEK MODELS
            AIModel(
                id: "deepseek-coder-1.3b-instruct-q4-k-m",
                name: "DeepSeek Coder 1.3B",
                description: "Lightweight code generation model optimized for mobile",
                huggingFaceRepo: "TheBloke/deepseek-coder-1.3b-instruct-GGUF",
                filename: "deepseek-coder-1.3b-instruct.Q4_K_M.gguf",
                sizeInBytes: 783_741_952, // ~747MB
                type: .code,
                tags: ["code", "programming", "mobile", "1.3b"],
                isGated: false,
                provider: .deepseek
            ),
            
            AIModel(
                id: "deepseek-llm-7b-instruct-q4-k-m",
                name: "DeepSeek LLM 7B Instruct",
                description: "DeepSeek's instruction-tuned language model",
                huggingFaceRepo: "TheBloke/deepseek-llm-7b-instruct-GGUF",
                filename: "deepseek-llm-7b-instruct.Q4_K_M.gguf",
                sizeInBytes: 3_800_000_000, // ~3.8GB
                type: .general,
                tags: ["deepseek", "instruct", "7b"],
                isGated: false,
                provider: .deepseek
            ),
            
            // BIGCODE MODELS
            AIModel(
                id: "starcoder2-3b-q4-k-m",
                name: "StarCoder2 3B",
                description: "Advanced code model supporting 600+ programming languages",
                huggingFaceRepo: "TheBloke/starcoder2-3b-GGUF",
                filename: "starcoder2-3b.Q4_K_M.gguf",
                sizeInBytes: 1_714_126_848, // ~1.6GB
                type: .code,
                tags: ["starcoder", "multilingual", "programming", "3b"],
                isGated: false,
                provider: .bigcode
            ),
            
            AIModel(
                id: "starcoder2-7b-q4-k-m",
                name: "StarCoder2 7B",
                description: "Larger StarCoder2 model for advanced code generation",
                huggingFaceRepo: "TheBloke/starcoder2-7b-GGUF",
                filename: "starcoder2-7b.Q4_K_M.gguf",
                sizeInBytes: 3_800_000_000, // ~3.8GB
                type: .code,
                tags: ["starcoder", "multilingual", "programming", "7b"],
                isGated: false,
                provider: .bigcode
            ),
            
            // APPLE MODELS
            AIModel(
                id: "mobilevit-small",
                name: "MobileViT Small",
                description: "Efficient vision transformer optimized for mobile",
                huggingFaceRepo: "apple/mobilevit-small", 
                filename: "pytorch_model.bin",
                sizeInBytes: 24_000_000, // ~23MB
                type: .general,
                tags: ["vision", "mobile", "apple", "efficient"],
                isGated: false,
                provider: .apple
            ),
            
            // HUGGING FACE MODELS
            AIModel(
                id: "all-minilm-l6-v2",
                name: "All-MiniLM-L6-v2",
                description: "Lightweight sentence embeddings for mobile apps",
                huggingFaceRepo: "sentence-transformers/all-MiniLM-L6-v2",
                filename: "pytorch_model.bin",
                sizeInBytes: 90_917_138, // ~86.7MB
                type: .general,
                tags: ["embeddings", "mobile", "lightweight"],
                isGated: false,
                provider: .huggingFace
            ),
            
            // MICROSOFT MODELS
            AIModel(
                id: "phi-2-q4-k-m",
                name: "Phi-2",
                description: "Microsoft's efficient language model for mobile",
                huggingFaceRepo: "TheBloke/phi-2-GGUF",
                filename: "phi-2.Q4_K_M.gguf",
                sizeInBytes: 1_400_000_000, // ~1.4GB
                type: .general,
                tags: ["phi", "microsoft", "efficient", "2.7b"],
                isGated: false,
                provider: .microsoft
            ),
            
            // ANTHROPIC MODELS (Claude-inspired)
            AIModel(
                id: "claude-instant-1.1-q4-k-m",
                name: "Claude Instant 1.1",
                description: "Lightweight Claude-inspired model for mobile",
                huggingFaceRepo: "TheBloke/claude-instant-1.1-GGUF",
                filename: "claude-instant-1.1.Q4_K_M.gguf",
                sizeInBytes: 2_800_000_000, // ~2.8GB
                type: .general,
                tags: ["claude", "instant", "anthropic", "mobile"],
                isGated: false,
                provider: .anthropic
            )
        ]
    }
    
    func verifyModelAvailability(_ model: AIModel) async -> Bool {
        let url = constructHuggingFaceURL(repo: model.huggingFaceRepo, filename: model.filename)
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Model verification for \(model.name): Status \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("❌ Failed to verify model \(model.name): \(error)")
            return false
        }
    }
    
    func downloadModel(_ model: AIModel) {
        guard !activeDownloads.contains(where: { $0.key == model.id }) else { 
            return 
        }
        guard !isModelDownloaded(model.id) else { 
            return 
        }
        
        let url = constructHuggingFaceURL(repo: model.huggingFaceRepo, filename: model.filename)
        
        // Create download request with proper headers for Hugging Face
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
    }
    
    func cancelDownload(_ modelId: String) {
        guard let download = activeDownloads[modelId] else { return }
        download.task.cancel()
        activeDownloads.removeValue(forKey: modelId)
    }
    
    func deleteModel(_ modelId: String) {
        let modelURL = modelsDirectory.appendingPathComponent(modelId)
        try? FileManager.default.removeItem(at: modelURL)
        downloadedModels.remove(modelId)
        calculateStorageUsed()
        updateTotalStorage()
    }
    
    func isModelDownloaded(_ modelId: String) -> Bool {
        // First check our in-memory set
        if downloadedModels.contains(modelId) {
            // Verify the file actually exists on disk
            let modelPath = modelsDirectory.appendingPathComponent(modelId)
            let fileExists = FileManager.default.fileExists(atPath: modelPath.path)
            
            if !fileExists {
                // File was deleted externally, update our tracking
                print("⚠️ Model \(modelId) was in downloaded set but file missing, removing from set")
                downloadedModels.remove(modelId)
                return false
            }
            return true
        }
        
        // If not in set, check if file exists on disk (user might have copied it manually)
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        let fileExists = FileManager.default.fileExists(atPath: modelPath.path)
        
        if fileExists {
            // File exists but wasn't tracked, add it to our set
            print("✅ Found untracked model \(modelId) on disk, adding to downloaded set")
            downloadedModels.insert(modelId)
            return true
        }
        
        return false
    }
    
    /// Get the local path for a downloaded model
    func getLocalModelPath(modelId: String) -> URL? {
        guard isModelDownloaded(modelId) else { return nil }
        return modelsDirectory.appendingPathComponent(modelId)
    }
    
    /// Synchronize downloaded models with actual files on disk
    func synchronizeDownloadedModels() {
        print("🔄 Synchronizing downloaded models with file system...")
        
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            return
        }
        
        do {
            // Get all files in models directory
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let filesOnDisk = Set(contents.map { $0.lastPathComponent })
            
            // Remove models from set that don't exist on disk
            let modelsToRemove = downloadedModels.subtracting(filesOnDisk)
            for modelId in modelsToRemove {
                print("🗑️ Removing missing model from tracking: \(modelId)")
                downloadedModels.remove(modelId)
            }
            
            // Add models found on disk that aren't tracked
            let modelsToAdd = filesOnDisk.subtracting(downloadedModels)
            for modelId in modelsToAdd {
                let modelPath = modelsDirectory.appendingPathComponent(modelId)
                
                // Verify it's a reasonable model file (not a temporary file)
                if let attributes = try? FileManager.default.attributesOfItem(atPath: modelPath.path),
                   let fileSize = attributes[.size] as? Int64,
                   fileSize > 1024 * 1024 { // At least 1MB
                    print("✅ Adding found model to tracking: \(modelId)")
                    downloadedModels.insert(modelId)
                }
            }
            
            print("📊 Synchronized: \(downloadedModels.count) models tracked")
            
        } catch {
            print("❌ Error synchronizing downloaded models: \(error)")
        }
    }
    
    func loadDownloadedModels() {
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else { return }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
            downloadedModels = Set(contents.map { $0.lastPathComponent })
        } catch {
            print("Error loading downloaded models: \(error)")
        }
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var formattedFreeStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorage), countStyle: .file)
    }
    
    // MARK: - Testing and Debugging Methods
    
    func testModelURL(_ model: AIModel) async {
        let url = constructHuggingFaceURL(repo: model.huggingFaceRepo, filename: model.filename)
        print("🧪 Testing URL for \(model.name)")
        print("📍 URL: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.setValue("Offline-AI-ML-Playground/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
                print("📏 Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "Unknown")")
                print("📋 Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "Unknown")")
                
                switch httpResponse.statusCode {
                case 200:
                    print("✅ \(model.name): URL is accessible")
                case 404:
                    print("❌ \(model.name): File not found (404)")
                case 403:
                    print("⚠️ \(model.name): Access forbidden (403) - might need authentication")
                default:
                    print("⚠️ \(model.name): Unexpected status code \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("❌ \(model.name): Network error - \(error.localizedDescription)")
        }
        print("---")
    }
    
    func testAllModelURLs() async {
        print("🧪 Testing all Hugging Face model URLs...")
        print(String(repeating: "=", count: 50))
        
        for model in availableModels {
            await testModelURL(model)
        }
        
        print("🏁 URL testing completed!")
    }
    
    // MARK: - Private Methods
    
    private func createModelsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
            try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    func calculateStorageUsed() {
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            storageUsed = 0
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            storageUsed = contents.reduce(0.0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Double(size)
            }
        } catch {
            storageUsed = 0
        }
    }
    
    private func constructHuggingFaceURL(repo: String, filename: String) -> URL {
        let baseURL = "https://huggingface.co/\(repo)/resolve/main/\(filename)"
        return URL(string: baseURL)!
    }
    
    private func saveDownloadedModel(from location: URL, modelId: String) {
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            downloadedModels.insert(modelId)
            calculateStorageUsed()
            updateTotalStorage()
            
            print("Successfully saved model: \(modelId)")
        } catch {
            print("Error saving model \(modelId): \(error)")
        }
    }
    
    /// Update the total storage property to reflect the device's free storage
    func updateTotalStorage() {
        if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
            self.freeStorage = freeSpace.doubleValue
        } else {
            self.freeStorage = 0
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension ModelDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Find the model being downloaded first (synchronously)
        var targetModelId: String?
        
        // We need to access activeDownloads from main actor, but we can't make this function async
        // So we'll do a synchronous dispatch to main to get the modelId
        DispatchQueue.main.sync {
            for (modelId, download) in activeDownloads {
                if download.task == downloadTask {
                    targetModelId = modelId
                    break
                }
            }
        }
        
        guard let modelId = targetModelId else { 
            return 
        }
        
        // Move the file immediately (before switching actors) to prevent cleanup
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        var moveSuccess = false
        
        do {
            // Create models directory if needed
            if !FileManager.default.fileExists(atPath: modelsDirectory.path) {
                print("📁 Creating models directory...")
                try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ Models directory created")
            } else {
                print("📁 Models directory already exists")
            }
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("🗑️ Removing existing file...")
                try FileManager.default.removeItem(at: destinationURL)
                print("✅ Existing file removed")
            }
            
            // Check if temp file still exists before moving
            if !FileManager.default.fileExists(atPath: location.path) {
                throw NSError(domain: "ModelDownloadManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Temporary file no longer exists at \(location.path)"])
            }
            
            // Move the temporary file to our app directory
            print("📦 Moving file from \(location.path) to \(destinationURL.path)")
            try FileManager.default.moveItem(at: location, to: destinationURL)
            moveSuccess = true
            print("✅ Successfully saved model: \(modelId) to \(destinationURL.path)")
            
            // Verify file was moved
            let finalFileExists = FileManager.default.fileExists(atPath: destinationURL.path)
            print("✅ Final file verification: \(finalFileExists)")
        } catch {
            print("❌ Error saving model \(modelId): \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            moveSuccess = false
        }
        
        // Now update the UI state on main actor
        Task { @MainActor in
            if moveSuccess {
                downloadedModels.insert(modelId)
                calculateStorageUsed()
            }
            activeDownloads.removeValue(forKey: modelId)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
            for (modelId, download) in activeDownloads {
                if download.task == downloadTask {
                    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    
                    let updatedDownload = ModelDownload(
                        modelId: download.modelId,
                        progress: progress,
                        totalBytes: totalBytesExpectedToWrite,
                        downloadedBytes: totalBytesWritten,
                        speed: Double(bytesWritten), // Simplified speed calculation
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
            print("❌ Download failed with error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            
            if let urlError = error as? URLError {
                print("❌ URLError code: \(urlError.code.rawValue)")
                print("❌ URLError description: \(urlError.localizedDescription)")
            }
            
            Task { @MainActor in
                // Remove failed download from active downloads
                for (modelId, download) in activeDownloads {
                    if download.task == task {
                        print("❌ Removing failed download for model: \(modelId)")
                        activeDownloads.removeValue(forKey: modelId)
                        break
                    }
                }
            }
        } else {
            print("✅ Download completed successfully")
        }
    }
} 