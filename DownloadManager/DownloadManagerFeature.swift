//
//  DownloadManagerFeature.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Download Manager State
struct DownloadManagerState: Equatable {
    var availableModels: [AIModel] = AIModel.availableModels
    var downloadingModels: [String: DownloadProgress] = [:]
    var downloadedModels: [AIModel] = []
    var isRefreshing: Bool = false
    var refreshError: String?
    
    struct DownloadProgress: Equatable {
        let modelId: String
        let progress: Double
        let bytesDownloaded: Int64
        let totalBytes: Int64
        let isComplete: Bool
        
        var progressPercentage: String {
            String(format: "%.1f%%", progress * 100)
        }
        
        var formattedProgress: String {
            let downloaded = ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
            let total = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            return "\(downloaded) / \(total)"
        }
    }
}

// MARK: - Download Manager Actions
enum DownloadManagerAction: Equatable {
    case viewAppeared
    case refreshModels
    case downloadModel(AIModel)
    case cancelDownload(String)
    case deleteModel(AIModel)
    case retryDownload(String)
    
    // Internal actions
    case modelsRefreshed([AIModel])
    case refreshFailed(String)
    case downloadStarted(String)
    case downloadProgressUpdated(String, DownloadManagerState.DownloadProgress)
    case downloadCompleted(AIModel)
    case downloadFailed(String, String)
    case modelDeleted(String)
}

// MARK: - Download Manager Reducer
@MainActor
class DownloadManagerReducer: ObservableObject {
    @Published private(set) var state = DownloadManagerState()
    
    func send(_ action: DownloadManagerAction) {
        Task {
            await reduce(action)
        }
    }
    
    private func reduce(_ action: DownloadManagerAction) async {
        switch action {
        case .viewAppeared:
            // Load downloaded models and refresh available models
            await send(.refreshModels)
            
        case .refreshModels:
            state.isRefreshing = true
            
            // TODO: Implement actual model refresh from Hugging Face API
            // For now, simulate network delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await send(.modelsRefreshed(AIModel.availableModels))
            
        case let .modelsRefreshed(models):
            state.availableModels = models
            state.isRefreshing = false
            state.refreshError = nil
            
        case let .refreshFailed(error):
            state.isRefreshing = false
            state.refreshError = error
            
        case let .downloadModel(model):
            // Start download
            state.downloadingModels[model.id] = DownloadManagerState.DownloadProgress(
                modelId: model.id,
                progress: 0.0,
                bytesDownloaded: 0,
                totalBytes: model.estimatedSize,
                isComplete: false
            )
            
            await send(.downloadStarted(model.id))
            
            // TODO: Implement actual download logic
            // For now, simulate download progress
            await simulateDownload(for: model)
            
        case let .downloadStarted(modelId):
            print("Download started for model: \(modelId)")
            
        case let .downloadProgressUpdated(modelId, progress):
            state.downloadingModels[modelId] = progress
            
            if progress.isComplete {
                // Find the model and mark it as downloaded
                if let modelIndex = state.availableModels.firstIndex(where: { $0.id == modelId }) {
                    var downloadedModel = state.availableModels[modelIndex]
                    // TODO: Update model with local path
                    state.downloadedModels.append(downloadedModel)
                    state.downloadingModels.removeValue(forKey: modelId)
                    await send(.downloadCompleted(downloadedModel))
                }
            }
            
        case let .downloadCompleted(model):
            print("Download completed for model: \(model.displayName)")
            
        case let .downloadFailed(modelId, error):
            state.downloadingModels.removeValue(forKey: modelId)
            print("Download failed for model \(modelId): \(error)")
            
        case let .cancelDownload(modelId):
            state.downloadingModels.removeValue(forKey: modelId)
            // TODO: Cancel actual download task
            
        case let .deleteModel(model):
            // Remove from downloaded models
            state.downloadedModels.removeAll { $0.id == model.id }
            
            // TODO: Delete actual model files
            await send(.modelDeleted(model.id))
            
        case let .retryDownload(modelId):
            if let model = state.availableModels.first(where: { $0.id == modelId }) {
                await send(.downloadModel(model))
            }
            
        case let .modelDeleted(modelId):
            print("Model deleted: \(modelId)")
        }
    }
    
    private func simulateDownload(for model: AIModel) async {
        let totalSteps = 10
        
        for step in 1...totalSteps {
            let progress = Double(step) / Double(totalSteps)
            let bytesDownloaded = Int64(Double(model.estimatedSize) * progress)
            
            let progressUpdate = DownloadManagerState.DownloadProgress(
                modelId: model.id,
                progress: progress,
                bytesDownloaded: bytesDownloaded,
                totalBytes: model.estimatedSize,
                isComplete: step == totalSteps
            )
            
            await send(.downloadProgressUpdated(model.id, progressUpdate))
            
            // Simulate download time
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
} 