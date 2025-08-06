//
//  UniversalModelDownloader.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation
import Combine

/// Universal downloader that handles all model formats (MLX, Multi-part, GGUF)
@MainActor
public class UniversalModelDownloader: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published public var isDownloading = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var currentFile = ""
    @Published public var downloadedBytes: Int64 = 0
    @Published public var totalBytes: Int64 = 0
    @Published public var downloadSpeed: Double = 0.0
    @Published public var lastError: String?
    
    // MARK: - Private Properties
    private var downloadTasks: [URLSessionDownloadTask] = []
    private var urlSession: URLSession?
    private var downloadStartTime = Date()
    private var fileProgress: [String: Double] = [:]
    private var pendingFiles: [(filename: String, url: URL)] = []
    private var completedFiles: Set<String> = []
    private var modelFormat: ModelFormatDetector.ModelFormat = .unknown
    private var destinationDirectory: URL?
    private var currentModel: AIModel?
    
    // MARK: - Initialization
    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600 // 1 hour for large models
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public Methods
    
    /// Download a model with automatic format detection
    public func downloadModel(_ model: AIModel) async throws {
        guard !isDownloading else {
            throw DownloadError.downloadInProgress
        }
        
        await MainActor.run {
            isDownloading = true
            downloadProgress = 0.0
            lastError = nil
            currentModel = model
            downloadStartTime = Date()
            fileProgress.removeAll()
            completedFiles.removeAll()
        }
        
        defer {
            Task { @MainActor in
                isDownloading = false
            }
        }
        
        // Detect model format
        modelFormat = ModelFormatDetector.detectFormat(from: model.huggingFaceRepo, modelInfo: model)
        print("🔍 Detected model format: \(modelFormat.displayName)")
        
        // Create destination directory
        destinationDirectory = ModelFileManager.shared.getMLXModelDirectory(for: model.id)
        try FileManager.default.createDirectory(at: destinationDirectory!, withIntermediateDirectories: true)
        
        // Get files to download based on format
        let urls = ModelFormatDetector.getDownloadURLs(for: model, format: modelFormat)
        
        if modelFormat == .multiPartSafetensors {
            // For multi-part models, first download the index file
            try await downloadMultiPartModel(model: model)
        } else {
            // For other formats, download all files
            try await downloadFiles(urls: urls)
        }
        
        // Create marker file
        let markerPath = ModelFileManager.shared.getModelPath(for: model.id)
        try model.id.write(to: markerPath, atomically: true, encoding: .utf8)
        
        // Refresh downloaded models
        ModelFileManager.shared.refreshDownloadedModels()
        
        print("✅ Model download completed: \(model.name)")
    }
    
    /// Cancel all active downloads
    public func cancelDownload() {
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
        pendingFiles.removeAll()
        
        Task { @MainActor in
            isDownloading = false
            downloadProgress = 0.0
            lastError = "Download cancelled"
        }
    }
    
    // MARK: - Private Methods
    
    private func downloadFiles(urls: [URL]) async throws {
        pendingFiles = urls.map { (filename: $0.lastPathComponent, url: $0) }
        totalBytes = Int64(urls.count * 100_000_000) // Estimate 100MB per file
        
        // Download files sequentially to avoid overwhelming the server
        for (filename, url) in pendingFiles {
            await MainActor.run {
                currentFile = filename
            }
            
            do {
                try await downloadFile(from: url, filename: filename)
                completedFiles.insert(filename)
                
                await MainActor.run {
                    downloadProgress = Double(completedFiles.count) / Double(pendingFiles.count)
                }
            } catch {
                // Skip optional files that fail
                let isRequired = modelFormat.requiredFiles.contains(filename)
                if isRequired {
                    throw error
                } else {
                    print("⚠️ Optional file not found: \(filename)")
                }
            }
        }
    }
    
    private func downloadFile(from url: URL, filename: String) async throws {
        guard let session = urlSession else {
            throw ModelError.invalidModel("URLSession not initialized")
        }
        let (tempURL, response) = try await session.download(from: url)
        
        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 404 {
                throw DownloadError.fileNotFound(filename)
            } else if httpResponse.statusCode != 200 {
                throw ModelError.networkError("Failed to download \(filename): HTTP \(httpResponse.statusCode)")
            }
        }
        
        // Move to destination
        let destURL = destinationDirectory!.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        
        print("✅ Downloaded: \(filename)")
    }
    
    private func downloadMultiPartModel(model: AIModel) async throws {
        // First download the index file to determine parts
        guard let indexURL = URL(string: "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/model.safetensors.index.json") else {
            throw ModelError.invalidModel("Invalid URL for model index")
        }
        
        guard let session = urlSession else {
            throw ModelError.invalidModel("URLSession not initialized")
        }
        let (tempURL, _) = try await session.download(from: indexURL)
        let indexData = try Data(contentsOf: tempURL)
        let destURL = destinationDirectory!.appendingPathComponent("model.safetensors.index.json")
        try indexData.write(to: destURL)
        
        // Parse index to find all parts
        if let indexJSON = try JSONSerialization.jsonObject(with: indexData) as? [String: Any],
           let weightMap = indexJSON["weight_map"] as? [String: String] {
            
            // Get unique part filenames
            let partFiles = Set(weightMap.values).sorted()
            print("📦 Found \(partFiles.count) model parts to download")
            
            // Build URLs for all parts and other files
            var urls: [URL] = []
            let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main"
            
            // Add model parts
            for partFile in partFiles {
                if let url = URL(string: "\(baseURL)/\(partFile)") {
                    urls.append(url)
                }
            }
            
            // Add other required files
            for filename in modelFormat.requiredFiles + modelFormat.optionalFiles {
                if filename != "model.safetensors.index.json" { // Already downloaded
                    if let url = URL(string: "\(baseURL)/\(filename)") {
                        urls.append(url)
                    }
                }
            }
            
            // Download all files
            try await downloadFiles(urls: urls)
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension UniversalModelDownloader: URLSessionDownloadDelegate {
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            // Update progress for current file
            if let filename = downloadTask.originalRequest?.url?.lastPathComponent {
                fileProgress[filename] = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                
                // Calculate overall progress
                let totalProgress = fileProgress.values.reduce(0, +) / Double(max(pendingFiles.count, 1))
                downloadProgress = totalProgress
                
                // Calculate download speed
                let elapsed = Date().timeIntervalSince(downloadStartTime)
                if elapsed > 0 {
                    downloadSpeed = Double(totalBytesWritten) / elapsed
                }
                
                downloadedBytes = totalBytesWritten
                if totalBytesExpectedToWrite > 0 {
                    totalBytes = totalBytesExpectedToWrite
                }
            }
        }
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // File handling is done in the async download methods
    }
    
    public nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
                print("❌ Download error: \(error)")
            }
        }
    }
}

// MARK: - Download Errors
enum DownloadError: LocalizedError {
    case downloadInProgress
    case fileNotFound(String)
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .downloadInProgress:
            return "A download is already in progress"
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        case .invalidFormat:
            return "Unknown or unsupported model format"
        }
    }
}