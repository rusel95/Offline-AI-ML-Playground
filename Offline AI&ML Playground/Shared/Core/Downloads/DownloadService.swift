//
//  DownloadService.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os

/// Service responsible for downloading model files
@MainActor
public class DownloadService: NSObject, ObservableObject {
    
    @Published public private(set) var activeDownloads: [String: DownloadProgress] = [:]
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "DownloadService")
    private var urlSession: URLSession!
    private var progressTrackers: [URLSessionTask: DownloadProgressTracker] = [:]
    private var modelTaskMapping: [String: URLSessionTask] = [:]
    private let progressUpdateThrottle: TimeInterval = 0.1
    private var lastProgressUpdate: [URLSessionTask: Date] = [:]
    
    public override init() {
        super.init()
        setupURLSession()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    /// Start downloading a model
    public func downloadModel(_ model: AIModel, from url: URL, resumeData: Data? = nil) -> URLSessionDownloadTask {
        
        let task: URLSessionDownloadTask
        
        if let resumeData = resumeData {
            logger.info("Resuming download for model: \(model.name)")
            task = urlSession.downloadTask(withResumeData: resumeData)
        } else {
            logger.info("Starting new download for model: \(model.name) from \(url)")
            task = urlSession.downloadTask(with: url)
        }
        
        // Create progress tracker
        progressTrackers[task] = DownloadProgressTracker()
        modelTaskMapping[model.id] = task
        
        // Create initial progress entry
        let progress = DownloadProgress(
            modelId: model.id,
            progress: 0.0,
            totalBytes: 0,
            downloadedBytes: 0,
            speed: 0.0,
            task: task
        )
        activeDownloads[model.id] = progress
        
        task.resume()
        return task
    }
    
    /// Cancel a download
    public func cancelDownload(modelId: String) {
        guard let task = modelTaskMapping[modelId] else { return }
        
        task.cancel()
        
        // Clean up
        activeDownloads.removeValue(forKey: modelId)
        progressTrackers.removeValue(forKey: task)
        modelTaskMapping.removeValue(forKey: modelId)
        lastProgressUpdate.removeValue(forKey: task)
        
        logger.info("Cancelled download for model: \(modelId)")
    }
    
    /// Get download progress for a model
    public func getProgress(for modelId: String) -> DownloadProgress? {
        return activeDownloads[modelId]
    }
    
    /// Check if a model is currently downloading
    public func isDownloading(modelId: String) -> Bool {
        return activeDownloads[modelId] != nil
    }
}

// MARK: - URLSessionDownloadDelegate
extension DownloadService: URLSessionDownloadDelegate {
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        Task { @MainActor in
            // Find the model ID for this task
            let modelId = modelTaskMapping.first(where: { $0.value == downloadTask })?.key
            
            guard let modelId = modelId else {
                logger.error("Could not find model ID for completed download")
                return
            }
            
            // Notify completion through a delegate or notification
            NotificationCenter.default.post(
                name: .modelDownloadCompleted,
                object: nil,
                userInfo: [
                    "modelId": modelId,
                    "location": location
                ]
            )
            
            // Clean up
            activeDownloads.removeValue(forKey: modelId)
            progressTrackers.removeValue(forKey: downloadTask)
            modelTaskMapping.removeValue(forKey: modelId)
            lastProgressUpdate.removeValue(forKey: downloadTask)
            
            logger.info("Download completed for model: \(modelId)")
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
            // Throttle updates
            let now = Date()
            if let lastUpdate = lastProgressUpdate[downloadTask],
               now.timeIntervalSince(lastUpdate) < progressUpdateThrottle {
                return
            }
            
            lastProgressUpdate[downloadTask] = now
            
            // Update progress tracker
            if let tracker = progressTrackers[downloadTask] {
                tracker.addSample(bytes: bytesWritten)
                
                // Find model ID
                if let modelId = modelTaskMapping.first(where: { $0.value == downloadTask })?.key {
                    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    let speed = tracker.getAverageSpeed()
                    
                    let downloadProgress = DownloadProgress(
                        modelId: modelId,
                        progress: progress,
                        totalBytes: totalBytesExpectedToWrite,
                        downloadedBytes: totalBytesWritten,
                        speed: speed,
                        task: downloadTask
                    )
                    
                    activeDownloads[modelId] = downloadProgress
                }
            }
        }
    }
    
    public nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        
        Task { @MainActor in
            // Find model ID
            let modelId = modelTaskMapping.first(where: { $0.value == task })?.key
            
            // Extract resume data if available
            let nsError = error as NSError
            let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
            
            // Notify error through notification
            NotificationCenter.default.post(
                name: .modelDownloadFailed,
                object: nil,
                userInfo: [
                    "modelId": modelId ?? "",
                    "error": error,
                    "resumeData": resumeData as Any
                ]
            )
            
            // Clean up
            if let modelId = modelId {
                activeDownloads.removeValue(forKey: modelId)
                modelTaskMapping.removeValue(forKey: modelId)
            }
            progressTrackers.removeValue(forKey: task)
            lastProgressUpdate.removeValue(forKey: task)
            
            logger.error("Download failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types
public struct DownloadProgress {
    public let modelId: String
    public let progress: Double
    public let totalBytes: Int64
    public let downloadedBytes: Int64
    public let speed: Double
    public let task: URLSessionDownloadTask
    
    public var formattedSpeed: String {
        if speed < 1024 {
            return "\(Int(speed)) B/s"
        } else if speed < 1024 * 1024 {
            return "\(Int(speed / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        }
    }
    
    public var formattedProgress: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "\(downloaded) / \(total)"
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let modelDownloadCompleted = Notification.Name("modelDownloadCompleted")
    static let modelDownloadFailed = Notification.Name("modelDownloadFailed")
}