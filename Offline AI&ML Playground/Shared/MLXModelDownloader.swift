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
    @Published var downloadSpeed: Double = 0.0 // bytes per second
    
    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession
    private var currentFileIndex = 0
    private var totalFiles = 0
    private var fileProgress: [String: Double] = [:]
    private nonisolated let continuationStore = ContinuationStore()
    private var speedTracker = SpeedTracker()
    
    /// Track download speed
    private struct SpeedTracker {
        private var samples: [(timestamp: Date, bytes: Int64)] = []
        private let maxSamples = 10
        
        mutating func addSample(bytes: Int64) {
            let now = Date()
            samples.append((now, bytes))
            
            // Keep only recent samples
            if samples.count > maxSamples {
                samples.removeFirst()
            }
        }
        
        func calculateSpeed() -> Double {
            guard samples.count >= 2 else { return 0 }
            
            let recent = samples.suffix(5) // Use last 5 samples for smoothing
            guard recent.count >= 2,
                  let first = recent.first,
                  let last = recent.last else { return 0 }
            
            let timeDiff = last.timestamp.timeIntervalSince(first.timestamp)
            guard timeDiff > 0 else { return 0 }
            
            let bytesDiff = last.bytes - first.bytes
            return Double(bytesDiff) / timeDiff
        }
        
        mutating func reset() {
            samples.removeAll()
        }
    }
    
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
        downloadSpeed = 0.0
        speedTracker.reset()
        lastError = nil
        
        defer {
            isDownloading = false
            downloadSpeed = 0.0
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
                print("📄 Starting download of \(filename) (\(index + 1)/\(totalFiles))")
                
                try await downloadFile(
                    filename: filename,
                    from: model.huggingFaceRepo,
                    to: mlxDir
                )
                
                fileProgress[filename] = 1.0
                updateOverallProgress()
                print("✅ Completed \(filename) - Overall progress: \(Int(downloadProgress * 100))%")
                
                // Reset speed tracker after each file
                speedTracker.reset()
                
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
        let completedFiles = fileProgress.values.filter { $0 >= 1.0 }.count
        
        // Calculate the average progress of incomplete files
        let incompleteFiles = fileProgress.filter { $0.value < 1.0 }
        let incompleteProgress = incompleteFiles.isEmpty ? 0.0 : incompleteFiles.values.reduce(0, +) / Double(incompleteFiles.count)
        
        // Overall progress = completed files + average progress of current file(s)
        let newProgress = (Double(completedFiles) + incompleteProgress) / Double(totalFiles)
        
        // Only update and log if progress changed significantly (at least 1%)
        let oldProgressPercent = Int(downloadProgress * 100)
        let newProgressPercent = Int(newProgress * 100)
        
        // Only update published value if percentage changed
        if newProgressPercent != oldProgressPercent {
            downloadProgress = newProgress
            print("📈 Progress update: \(completedFiles)/\(totalFiles) files complete, Overall: \(newProgressPercent)%")
        }
        // Do NOT update downloadProgress if percentage hasn't changed to avoid UI spam
    }
    
    /// Cancel current download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadStatus = "Download cancelled"
    }
    
    /// Format speed for display
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1024 * 1024 {
            return "\(Int(bytesPerSecond / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / (1024 * 1024))
        }
    }
}

// MARK: - Download Progress Tracking

extension MLXModelDownloader: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let fileProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        Task { @MainActor in
            // Update speed tracking
            self.speedTracker.addSample(bytes: totalBytesWritten)
            self.downloadSpeed = self.speedTracker.calculateSpeed()
            
            // Update file progress for current file
            if let currentUrl = downloadTask.currentRequest?.url?.lastPathComponent {
                let previousProgress = self.fileProgress[currentUrl] ?? 0.0
                self.fileProgress[currentUrl] = fileProgress
                self.updateOverallProgress()
                
                // Log individual file progress every 10%
                let previousPercentage = Int(previousProgress * 100)
                let currentPercentage = Int(fileProgress * 100)
                
                if currentPercentage >= previousPercentage + 10 {
                    print("📊 File progress: \(currentUrl) - \(currentPercentage)%")
                    print("   Downloaded: \(ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file))")
                    
                    // Log speed
                    let speedStr = self.formatSpeed(self.downloadSpeed)
                    print("   Speed: \(speedStr)")
                }
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