//
//  PreviewDownloadManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation

// MARK: - Preview Download Manager
/// Mock download manager for previews and testing
/// This provides a consistent mock implementation across all preview files
class PreviewDownloadManager: ModelDownloadManager {
    private var _downloadedModels: Set<String> = []
    private var _activeDownloads: [String: ModelDownload] = [:]
    
    override var downloadedModels: Set<String> {
        get { _downloadedModels }
        set { _downloadedModels = newValue }
    }
    
    override var activeDownloads: [String: ModelDownload] {
        get { _activeDownloads }
        set { _activeDownloads = newValue }
    }
    
    func setDownloaded(_ modelId: String) {
        _downloadedModels.insert(modelId)
    }
    
    func setDownloading(_ modelId: String, progress: Double) {
        let mockDownload = ModelDownload(
            modelId: modelId,
            progress: progress,
            totalBytes: 1_000_000_000,
            downloadedBytes: Int64(progress * 1_000_000_000),
            speed: 1_000_000,
            task: URLSession.shared.downloadTask(with: URL(string: "https://example.com")!)
        )
        _activeDownloads[modelId] = mockDownload
    }
} 