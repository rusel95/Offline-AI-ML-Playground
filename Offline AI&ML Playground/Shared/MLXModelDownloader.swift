//
//  MLXModelDownloader.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation

/// Thread-safe continuation storage
private class ContinuationStore {
    private var continuation: CheckedContinuation<URL, Error>?
    private let lock = NSLock()
    
    func set(_ continuation: CheckedContinuation<URL, Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }
    
    func takeAndResume(returning value: URL) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(returning: value)
        continuation = nil
    }
    
    func takeAndResume(throwing error: Error) {
        lock.lock()
        defer { lock.unlock() }
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

/// Specialized downloader for MLX community models from HuggingFace
@MainActor
class MLXModelDownloader: NSObject, ObservableObject {
    
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = ""
    @Published var lastError: String?
    
    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession
    private var currentFileIndex = 0
    private var totalFiles = 0
    private var fileProgress: [String: Double] = [:]
    private nonisolated let continuationStore = ContinuationStore()
    
    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.urlSession = URLSession(configuration: config)
        super.init()
        // Update session with delegate after super.init()
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    /// Download all necessary files for an MLX model
    func downloadMLXModel(_ model: AIModel) async throws {
        isDownloading = true
        downloadProgress = 0.0
        lastError = nil
        
        defer {
            isDownloading = false
        }
        
        print("🚀 Starting MLX model download for: \(model.name)")
        
        // Create the destination directory
        let mlxDir = ModelFileManager.shared.getMLXModelDirectory(for: model.id)
        try FileManager.default.createDirectory(at: mlxDir, withIntermediateDirectories: true)
        
        // Files to download for MLX models
        let requiredFiles = [
            "model.safetensors",
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json"
        ]
        
        self.totalFiles = requiredFiles.count
        self.currentFileIndex = 0
        self.fileProgress.removeAll()
        
        for (index, filename) in requiredFiles.enumerated() {
            self.currentFileIndex = index
            downloadStatus = "Downloading \(filename)..."
            
            do {
                try await downloadFile(
                    filename: filename,
                    from: model.huggingFaceRepo,
                    to: mlxDir
                )
                
                fileProgress[filename] = 1.0
                updateOverallProgress()
                
            } catch {
                // Some files are optional, only fail on critical files
                if filename == "model.safetensors" || filename == "config.json" {
                    throw error
                } else {
                    print("⚠️ Optional file not found: \(filename)")
                    fileProgress[filename] = 1.0  // Mark as complete even if optional
                    updateOverallProgress()
                }
            }
        }
        
        // Create marker file
        let markerPath = ModelFileManager.shared.getModelPath(for: model.id)
        try model.id.write(to: markerPath, atomically: true, encoding: .utf8)
        
        // Refresh downloaded models
        ModelFileManager.shared.refreshDownloadedModels()
        
        downloadStatus = "Download completed!"
        print("✅ Successfully downloaded MLX model: \(model.name)")
    }
    
    /// Download a single file from HuggingFace
    private func downloadFile(filename: String, from repo: String, to directory: URL) async throws {
        // Construct the proper HuggingFace URL
        let urlString = "https://huggingface.co/\(repo)/resolve/main/\(filename)"
        
        guard let url = URL(string: urlString) else {
            throw ModelError.networkError("Invalid URL: \(urlString)")
        }
        
        print("📥 Downloading: \(urlString)")
        
        // Check if file already exists
        let destPath = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: destPath.path) {
            print("✅ File already exists: \(filename)")
            fileProgress[filename] = 1.0
            updateOverallProgress()
            return
        }
        
        // Reset file progress
        fileProgress[filename] = 0.0
        
        // Use downloadTask for progress tracking
        let request = URLRequest(url: url)
        let downloadedURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.continuationStore.set(continuation)
            let task = urlSession.downloadTask(with: request)
            self.downloadTask = task
            task.resume()
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: downloadedURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        print("📊 Downloaded file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
        
        // Verify it's not an error page
        if fileSize < 1000 && filename == "model.safetensors" {
            // Read the content to check if it's an error
            if let content = try? String(contentsOf: downloadedURL, encoding: .utf8) {
                print("⚠️ Small file content: \(content.prefix(100))")
                throw ModelError.networkError("Downloaded file too small - might be an error page")
            }
        }
        
        // Move to destination
        try FileManager.default.moveItem(at: downloadedURL, to: destPath)
        print("✅ Saved: \(filename)")
    }
    
    /// Update overall download progress based on individual file progress
    private func updateOverallProgress() {
        let baseProgress = Double(currentFileIndex) / Double(totalFiles)
        let currentFileProgress = fileProgress.values.reduce(0, +) / Double(max(fileProgress.count, 1))
        let fileWeight = 1.0 / Double(totalFiles)
        
        downloadProgress = baseProgress + (currentFileProgress * fileWeight)
    }
    
    /// Cancel current download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadStatus = "Download cancelled"
    }
}

// MARK: - Download Progress Tracking

extension MLXModelDownloader: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fileProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            // Update file progress for current file
            if let currentUrl = downloadTask.currentRequest?.url?.lastPathComponent {
                self.fileProgress[currentUrl] = fileProgress
                self.updateOverallProgress()
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Resume the continuation with the downloaded file location
        continuationStore.takeAndResume(returning: location)
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Check if it's a 404 or 401 error
            if let httpResponse = task.response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    continuationStore.takeAndResume(throwing: ModelError.networkError("File not found"))
                } else if httpResponse.statusCode == 401 {
                    continuationStore.takeAndResume(throwing: ModelError.authenticationError("Authentication required. Model might be gated."))
                } else if httpResponse.statusCode != 200 {
                    continuationStore.takeAndResume(throwing: ModelError.networkError("Download failed with status: \(httpResponse.statusCode)"))
                } else {
                    continuationStore.takeAndResume(throwing: error)
                }
                
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                    self.isDownloading = false
                }
            } else {
                continuationStore.takeAndResume(throwing: error)
                
                Task { @MainActor in
                    self.lastError = error.localizedDescription
                    self.isDownloading = false
                }
            }
        }
    }
}