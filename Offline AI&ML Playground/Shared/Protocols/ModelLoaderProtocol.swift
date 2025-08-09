//
//  ModelLoaderProtocol.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation

/// Protocol for model loading operations
@MainActor
public protocol ModelLoaderProtocol {
    var isModelLoaded: Bool { get }
    var loadingProgress: Float { get }
    var loadingStatus: String { get }
    
    func loadModel(_ model: AIModel) async throws
    func unloadModel() async
    func switchModel(to model: AIModel) async throws
}

/// Protocol for model inference operations
@MainActor
public protocol ModelInferenceProtocol {
    func generateText(prompt: String, maxTokens: Int) async throws -> String
    func generateStreamingText(prompt: String, maxTokens: Int) -> AsyncThrowingStream<StreamingResponse, Error>
}

/// Protocol for model configuration
public protocol ModelConfigurationProtocol {
    func createConfiguration(for model: AIModel) throws -> Any
    func validateConfiguration(_ config: Any) -> Bool
}

/// Protocol for download management
@MainActor
public protocol DownloadManagerProtocol {
    var activeDownloads: [String: ModelDownload] { get }
    
    func downloadModel(_ model: AIModel) async throws
    func cancelDownload(_ modelId: String)
    func resumeDownload(_ modelId: String) async throws
}

/// Protocol for storage management
public protocol StorageManagerProtocol {
    func getModelPath(for modelId: String) -> URL?
    func isModelDownloaded(_ modelId: String) -> Bool
    func deleteModel(_ modelId: String) throws
    func getTotalStorageUsed() -> Int64
}

