//
//  MLXModelDownloader.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation

/// Specialized downloader for MLX community models from HuggingFace
@MainActor
class MLXModelDownloader: NSObject, ObservableObject {
    
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus = ""
    @Published var lastError: String?
    
    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession
    
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
        
        let totalFiles = requiredFiles.count
        var downloadedFiles = 0
        
        for filename in requiredFiles {
            downloadStatus = "Downloading \(filename)..."
            
            do {
                try await downloadFile(
                    filename: filename,
                    from: model.huggingFaceRepo,
                    to: mlxDir
                )
                
                downloadedFiles += 1
                downloadProgress = Double(downloadedFiles) / Double(totalFiles)
                
            } catch {
                // Some files are optional, only fail on critical files
                if filename == "model.safetensors" || filename == "config.json" {
                    throw error
                } else {
                    print("⚠️ Optional file not found: \(filename)")
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
            return
        }
        
        // Download the file
        let (tempURL, response) = try await urlSession.download(from: url)
        
        // Check response
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 Response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 404 {
                throw ModelError.networkError("File not found: \(filename)")
            } else if httpResponse.statusCode == 401 {
                throw ModelError.authenticationError("Authentication required. Model might be gated.")
            } else if httpResponse.statusCode != 200 {
                throw ModelError.networkError("Download failed with status: \(httpResponse.statusCode)")
            }
        }
        
        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        print("📊 Downloaded file size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
        
        // Verify it's not an error page
        if fileSize < 1000 && filename == "model.safetensors" {
            // Read the content to check if it's an error
            if let content = try? String(contentsOf: tempURL, encoding: .utf8) {
                print("⚠️ Small file content: \(content.prefix(100))")
                throw ModelError.networkError("Downloaded file too small - might be an error page")
            }
        }
        
        // Move to destination
        try FileManager.default.moveItem(at: tempURL, to: destPath)
        print("✅ Saved: \(filename)")
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
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            self.downloadProgress = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the async download method
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.lastError = error.localizedDescription
                self.isDownloading = false
            }
        }
    }
}