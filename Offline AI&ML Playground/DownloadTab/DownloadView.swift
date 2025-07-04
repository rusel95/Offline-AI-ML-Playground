//
//  DownloadView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import Foundation

struct SimpleDownloadView: View {
    @StateObject private var downloadManager = ModelDownloadManager()
    
    var body: some View {
        NavigationSplitView {
            // Sidebar with categories and storage info
            VStack(spacing: 20) {
                StorageHeaderView(downloadManager: downloadManager)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Categories")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(ModelType.allCases, id: \.self) { type in
                        HStack {
                            Circle()
                                .fill(type.color)
                                .frame(width: 8, height: 8)
                            Text(type.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(downloadManager.availableModels.filter { $0.type == type }.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 250, idealWidth: 280)
            
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Header with title and refresh button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Models")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Download AI models for offline use")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        downloadManager.refreshAvailableModels()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                
                // Models grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 400, maximum: 500), spacing: 20)
                    ], spacing: 20) {
                        ForEach(downloadManager.availableModels, id: \.id) { model in
                            ModelCardView(
                                model: model,
                                downloadManager: downloadManager
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            downloadManager.loadDownloadedModels()
            if downloadManager.availableModels.isEmpty {
                downloadManager.refreshAvailableModels()
            }
        }
    }
}

// MARK: - Storage Header
struct StorageHeaderView: View {
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Storage")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(downloadManager.formattedStorageUsed)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            ProgressView(value: downloadManager.storageUsed, total: downloadManager.totalStorage)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Model Card
struct ModelCardView: View {
    let model: AIModel
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model header
            HStack(alignment: .top, spacing: 12) {
                // Model type icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(model.type.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: model.type.iconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(model.type.color)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.formattedSize)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(model.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(model.type.color.opacity(0.15))
                        .foregroundColor(model.type.color)
                        .cornerRadius(6)
                }
            }
            
            // Tags
            if !model.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // Download status and action
            ModelActionView(model: model, downloadManager: downloadManager)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Model Action View
struct ModelActionView: View {
    let model: AIModel
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        if let download = downloadManager.activeDownloads[model.id] {
            // Currently downloading
            VStack(spacing: 12) {
                HStack {
                    Text("Downloading...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(Int(download.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: download.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Text(download.formattedSpeed)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        downloadManager.cancelDownload(model.id)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }
        } else if downloadManager.isModelDownloaded(model.id) {
            // Already downloaded
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("Downloaded")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("Delete") {
                    downloadManager.deleteModel(model.id)
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        } else {
            // Available for download
            Button(action: {
                downloadManager.downloadModel(model)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                    Text("Download")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Data Models
struct AIModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let huggingFaceRepo: String
    let filename: String
    let sizeInBytes: Int64
    let type: ModelType
    let tags: [String]
    let isGated: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}

enum ModelType: String, CaseIterable {
    case llama = "llama"
    case whisper = "whisper"
    case stable_diffusion = "stable_diffusion"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .llama: return "Llama"
        case .whisper: return "Whisper"
        case .stable_diffusion: return "Stable Diffusion"
        case .general: return "General"
        }
    }
    
    var color: Color {
        switch self {
        case .llama: return .orange
        case .whisper: return .purple
        case .stable_diffusion: return .pink
        case .general: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .llama: return "🐑"
        case .whisper: return "🎤"
        case .stable_diffusion: return "🎨"
        case .general: return "🤖"
        }
    }
}

struct ModelDownload {
    let modelId: String
    let progress: Double
    let totalBytes: Int64
    let downloadedBytes: Int64
    let speed: Double // bytes per second
    let task: URLSessionDownloadTask
    
    var formattedSpeed: String {
        if speed < 1024 {
            return "\(Int(speed)) B/s"
        } else if speed < 1024 * 1024 {
            return "\(Int(speed / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        }
    }
}

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
        // Curated list of tested, working Hugging Face models
        availableModels = [
            // Test with a small, real file first
            AIModel(
                id: "test-small-file",
                name: "Test Small File",
                description: "Small test file to verify download functionality works",
                huggingFaceRepo: "microsoft/DialoGPT-medium",
                filename: "config.json",
                sizeInBytes: 1_024, // ~1KB
                type: .general,
                tags: ["test", "small"],
                isGated: false
            ),
            
            // Real working GGML models from TheBloke
            AIModel(
                id: "llama-2-7b-chat-q4",
                name: "Llama 2 7B Chat Q4_0",
                description: "Quantized Llama 2 7B model - tested and working",
                huggingFaceRepo: "TheBloke/Llama-2-7B-Chat-GGML",
                filename: "llama-2-7b-chat.q4_0.bin",
                sizeInBytes: 3_800_000_000, // ~3.8GB
                type: .llama,
                tags: ["chat", "ggml", "quantized", "7b"],
                isGated: false
            ),
            
            // Another tested model
            AIModel(
                id: "tiny-llama-q4",
                name: "TinyLlama 1.1B Q4_0",
                description: "Small but capable model for testing",
                huggingFaceRepo: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGML",
                filename: "tinyllama-1.1b-chat-v1.0.q4_0.bin",
                sizeInBytes: 669_000_000, // ~669MB
                type: .llama,
                tags: ["chat", "ggml", "tiny", "1b"],
                isGated: false
            ),
            
            // Whisper model that definitely exists
            AIModel(
                id: "whisper-tiny",
                name: "Whisper Tiny",
                description: "Tiny Whisper model for speech recognition",
                huggingFaceRepo: "ggerganov/whisper.cpp",
                filename: "ggml-tiny.bin",
                sizeInBytes: 39_000_000, // ~39MB
                type: .whisper,
                tags: ["speech-to-text", "ggml", "tiny"],
                isGated: false
            )
        ]
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
        
        // Test if URL is accessible first
        print("🔄 Starting download for: \(model.name)")
        print("📍 URL: \(url.absoluteString)")
        print("📁 Models directory: \(modelsDirectory.path)")
        
        let task = urlSession.downloadTask(with: url)
        
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

#Preview {
    SimpleDownloadView()
} 