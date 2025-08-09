//
//  CoreProtocols.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation
import Combine

// MARK: - Model Management Protocols

@MainActor
protocol ModelCatalogProtocol {
    var availableModels: [AIModel] { get }
    func loadModels() async
    func searchModels(query: String) -> [AIModel]
    func getModel(by id: String) -> AIModel?
}

protocol ModelDownloadManagerProtocol {
    func downloadModel(_ model: AIModel) async throws
    func cancelDownload(for modelId: String)
    func getDownloadProgress(for modelId: String) -> Double?
    func isModelDownloaded(_ model: AIModel) -> Bool
}

// MARK: - Inference Protocols

protocol InferenceEngineProtocol {
    func loadModel(_ model: AIModel) async throws
    func unloadCurrentModel() async
    func generateText(prompt: String, maxTokens: Int) async throws -> String
    func generateTextStream(prompt: String, maxTokens: Int) -> AsyncThrowingStream<String, Error>
    var isModelLoaded: Bool { get }
    var currentModel: AIModel? { get }
}

// MARK: - Settings Protocols

@MainActor
protocol GenerationSettingsProtocol {
    var temperature: Float { get }
    var topP: Float { get }
    var maxOutputTokens: Int { get }
    var systemPrompt: String { get }
}

protocol SettingsStorageProtocol {
    func getValue<T>(for key: String, defaultValue: T) -> T
    func setValue<T>(_ value: T, for key: String)
    func removeValue(for key: String)
}

// MARK: - Chat Management Protocols

protocol ConversationStorageProtocol {
    func createNewConversation() async -> String
    func saveMessage(_ message: ChatMessage, to conversationId: String) async
    func loadConversation(_ id: String) async -> [ChatMessage]?
    func deleteConversation(_ id: String) async
    func listConversations() async -> [(id: String, date: Date, preview: String)]
}

@MainActor
protocol ContextBuilderProtocol {
    func buildContext(messages: [ChatMessage], maxTokens: Int, useFullHistory: Bool) -> String
    func estimateTokenCount(for text: String) -> Int
}

// MARK: - Memory Management Protocols

protocol MemoryManagerProtocol {
    func getMemoryUsage() -> (used: Double, total: Double)
    func performMemoryCleanup() async
    func shouldPerformCleanup(threshold: Double) -> Bool
}

// MARK: - Network Monitoring Protocols

protocol NetworkMonitorProtocol {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
    func startMonitoring()
    func stopMonitoring()
}

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
    case none
}

// MARK: - File Management Protocols

protocol ModelFileManagerProtocol {
    func getModelDirectory(for model: AIModel) -> URL
    func deleteModelFiles(for model: AIModel) async throws
    func calculateModelSize(for model: AIModel) async -> Int64
    func verifyModelIntegrity(for model: AIModel) async -> Bool
}