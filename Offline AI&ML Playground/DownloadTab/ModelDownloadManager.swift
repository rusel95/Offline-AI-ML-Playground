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
    @Published var totalStorage: Double = 100_000_000_000 // 100GB
    
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
        
        // Calculate initial storage
        calculateStorageUsed()
    }
    
    // MARK: - Public Methods
    
    func refreshAvailableModels() {
        // iPhone-compatible, lightweight models for mobile deployment
        availableModels = [
            // TINY TEST FILE (for connectivity testing)
            AIModel(
                id: "tiny-bert-config",
                name: "TinyBERT Config (Test)",
                description: "Small config file to test HuggingFace connectivity",
                huggingFaceRepo: "huawei-noah/TinyBERT_General_4L_312D",
                filename: "config.json",
                sizeInBytes: 1_500, // ~1.5KB
                type: .general,
                tags: ["test", "config", "bert"],
                isGated: false
            ),
            
            // MOBILE-OPTIMIZED LANGUAGE MODELS
            AIModel(
                id: "tinyllama-1.1b-chat-q4-k-m",
                name: "TinyLlama 1.1B Chat",
                description: "Ultra-lightweight chat model optimized for mobile devices",
                huggingFaceRepo: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
                filename: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
                sizeInBytes: 669_262_336, // ~638MB
                type: .llama,
                tags: ["chat", "mobile", "tiny", "1b"],
                isGated: false
            ),
            
            AIModel(
                id: "distilbert-base-uncased",
                name: "DistilBERT Mobile",
                description: "Lightweight BERT model perfect for mobile NLP tasks",
                huggingFaceRepo: "distilbert-base-uncased",
                filename: "pytorch_model.bin",
                sizeInBytes: 267_967_963, // ~255MB
                type: .general,
                tags: ["nlp", "mobile", "bert", "distilled"],
                isGated: false
            ),
            
            // SPEECH RECOGNITION (Mobile-friendly)
            AIModel(
                id: "whisper-tiny-ggml",
                name: "Whisper Tiny",
                description: "Ultra-fast speech recognition, perfect for mobile",
                huggingFaceRepo: "ggerganov/whisper.cpp",
                filename: "ggml-tiny.bin",
                sizeInBytes: 39_047_680, // ~37.2MB
                type: .whisper,
                tags: ["speech-to-text", "mobile", "fast", "lightweight"],
                isGated: false
            ),
            
            AIModel(
                id: "whisper-base-ggml",
                name: "Whisper Base",
                description: "Balanced speech model for mobile devices",
                huggingFaceRepo: "ggerganov/whisper.cpp",
                filename: "ggml-base.bin",
                sizeInBytes: 147_964_211, // ~141MB
                type: .whisper,
                tags: ["speech-to-text", "mobile", "balanced"],
                isGated: false
            ),
            
            // EMBEDDINGS (Mobile-optimized)
            AIModel(
                id: "all-minilm-l6-v2",
                name: "All-MiniLM-L6-v2",
                description: "Lightweight sentence embeddings for mobile apps",
                huggingFaceRepo: "sentence-transformers/all-MiniLM-L6-v2",
                filename: "pytorch_model.bin",
                sizeInBytes: 90_917_138, // ~86.7MB
                type: .general,
                tags: ["embeddings", "mobile", "lightweight"],
                isGated: false
            ),
            
            // MOBILE VISION/TEXT MODEL
            AIModel(
                id: "mobilevit-small",
                name: "MobileViT Small",
                description: "Efficient vision transformer optimized for mobile",
                huggingFaceRepo: "apple/mobilevit-small", 
                filename: "pytorch_model.bin",
                sizeInBytes: 24_000_000, // ~23MB
                type: .general,
                tags: ["vision", "mobile", "apple", "efficient"],
                isGated: false
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
            print("⚠️ Download already in progress for: \(model.id)")
            return 
        }
        guard !isModelDownloaded(model.id) else { 
            print("⚠️ Model already downloaded: \(model.id)")
            return 
        }
        
        let url = constructHuggingFaceURL(repo: model.huggingFaceRepo, filename: model.filename)
        
        // Enhanced logging for Hugging Face downloads
        print("🔄 Starting download for: \(model.name)")
        print("📍 Hugging Face URL: \(url.absoluteString)")
        print("📦 Repository: \(model.huggingFaceRepo)")
        print("📄 Filename: \(model.filename)")
        print("📏 Expected size: \(model.formattedSize)")
        print("📁 Models directory: \(modelsDirectory.path)")
        
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
        
        print("✅ Download task started for: \(model.name)")
        print("🔗 Task identifier: \(task.taskIdentifier)")
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
    }
    
    func isModelDownloaded(_ modelId: String) -> Bool {
        downloadedModels.contains(modelId)
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
                print("📊 Status Code: \(httpResponse.statusCode)")
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
    
    private func calculateStorageUsed() {
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
            
            print("Successfully saved model: \(modelId)")
        } catch {
            print("Error saving model \(modelId): \(error)")
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
            print("❌ Could not find model for completed download task")
            return 
        }
        
        print("📥 Download completed for model: \(modelId)")
        print("📁 Temporary file location: \(location.path)")
        print("📋 File exists at temp location: \(FileManager.default.fileExists(atPath: location.path))")
        
        // Move the file immediately (before switching actors) to prevent cleanup
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        print("📁 Target directory: \(modelsDirectory.path)")
        print("📁 Final destination: \(destinationURL.path)")
        
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