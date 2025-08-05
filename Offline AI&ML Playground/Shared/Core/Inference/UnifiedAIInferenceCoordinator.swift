//
//  UnifiedAIInferenceCoordinator.swift
//  Offline AI&ML Playground
//
//  Created on 2025-01-08.
//

import Foundation
import SwiftUI
import Combine

/// Enhanced AI inference coordinator using unified model loading system
@MainActor
public class UnifiedAIInferenceCoordinator: ObservableObject, ModelInferenceProtocol {
    
    @Published public var isModelLoaded: Bool = false
    @Published public var loadingProgress: Float = 0.0
    @Published public var loadingStatus: String = "Ready"
    @Published public var lastError: String?
    @Published public var currentLoaderInfo: String?
    
    private var currentLoader: UnifiedModelLoaderProtocol?
    private var loadedModel: LoadedModel?
    private var currentAIModel: AIModel?
    
    private let factory = ModelLoaderFactory.shared
    private let memoryManager = MemoryManager.shared
    
    public init() {}
    
    /// Load a model for inference using the best available loader
    public func loadModel(_ model: AIModel) async throws {
        do {
            loadingStatus = "Finding best loader..."
            loadingProgress = 0.1
            
            // Get the best loader for this model
            guard let loader = await factory.getLoader(for: model) else {
                throw UnifiedModelLoadError.unsupportedModel(model.name)
            }
            
            // Get loader information
            let loaderInfo = await factory.getLoaderInfo(for: model)
            currentLoaderInfo = loaderInfo.description
            loadingStatus = "Using \(loader.loaderName)"
            loadingProgress = 0.2
            
            // Get model path
            let modelPath = ModelPaths.shared.getModelPath(for: model.id)
            
            // Check if model files exist
            guard FileManager.default.fileExists(atPath: modelPath.path) else {
                throw UnifiedModelLoadError.modelNotFound(modelPath)
            }
            
            loadingStatus = "Loading model..."
            loadingProgress = 0.3
            
            // Load the model
            let loaded = try await loader.loadModel(model: model, modelPath: modelPath)
            
            // Store references
            self.currentLoader = loader
            self.loadedModel = loaded
            self.currentAIModel = model
            
            loadingProgress = 1.0
            loadingStatus = "Model loaded successfully"
            isModelLoaded = true
            
            // Log loader info
            if let info = currentLoaderInfo {
                print("📊 Loaded with: \(info)")
            }
            
        } catch {
            lastError = error.localizedDescription
            loadingStatus = "Failed to load model"
            loadingProgress = 0.0
            isModelLoaded = false
            throw error
        }
    }
    
    /// Unload the current model
    public func unloadModel() async {
        guard let loader = currentLoader, let model = loadedModel else { return }
        
        loadingStatus = "Unloading model..."
        await loader.unloadModel(model)
        
        currentLoader = nil
        loadedModel = nil
        currentAIModel = nil
        currentLoaderInfo = nil
        
        isModelLoaded = false
        loadingStatus = "Ready"
        loadingProgress = 0.0
    }
    
    /// Generate text using the loaded model
    public func generateText(prompt: String, maxTokens: Int) async throws -> String {
        guard let loader = currentLoader, let model = loadedModel else {
            throw UnifiedModelLoadError.loadingFailed("No model loaded")
        }
        
        var generatedText = ""
        
        for try await chunk in loader.generateText(
            prompt: prompt,
            model: model,
            maxTokens: maxTokens,
            temperature: 0.7
        ) {
            generatedText += chunk
        }
        
        return generatedText
    }
    
    /// Generate streaming text
    public func generateStreamingText(prompt: String, maxTokens: Int) -> AsyncThrowingStream<StreamingResponse, Error> {
        guard let loader = currentLoader, let model = loadedModel else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: UnifiedModelLoadError.loadingFailed("No model loaded"))
            }
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var tokenCount = 0
                    let _ = Date()
                    
                    for try await chunk in loader.generateText(
                        prompt: prompt,
                        model: model,
                        maxTokens: maxTokens,
                        temperature: 0.7
                    ) {
                        tokenCount += chunk.split(separator: " ").count
                        
                        var metrics = TokenMetrics()
                        metrics.update(tokenCount: tokenCount, currentTime: Date())
                        
                        let response = StreamingResponse(
                            text: chunk,
                            metrics: metrics
                        )
                        
                        continuation.yield(response)
                    }
                    
                    // Send completion
                    var finalMetrics = TokenMetrics()
                    finalMetrics.update(tokenCount: tokenCount, currentTime: Date())
                    finalMetrics.finalize()
                    
                    let finalResponse = StreamingResponse(
                        text: "",
                        metrics: finalMetrics
                    )
                    continuation.yield(finalResponse)
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Switch to a different model
    public func switchModel(to model: AIModel) async throws {
        // Unload current model
        await unloadModel()
        
        // Load new model
        try await loadModel(model)
    }
    
    /// Get the currently loaded model
    public var currentModel: AIModel? {
        return currentAIModel
    }
    
    /// Get information about which loader would be used for a model
    public func getLoaderInfo(for model: AIModel) async -> String {
        let info = await factory.getLoaderInfo(for: model)
        return info.description
    }
    
    /// Check if a model is supported
    public func isModelSupported(_ model: AIModel) async -> Bool {
        let info = await factory.getLoaderInfo(for: model)
        return info.supportsModel
    }
    
    /// Get memory usage of the current model
    public func getMemoryUsage() -> String {
        guard let loader = currentLoader, let model = loadedModel else {
            return "No model loaded"
        }
        
        if let bytes = loader.getMemoryUsage(for: model) {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .memory
            return formatter.string(fromByteCount: Int64(bytes))
        }
        
        return "Unknown"
    }
}