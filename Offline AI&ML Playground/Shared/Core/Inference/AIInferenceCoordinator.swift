//
//  AIInferenceCoordinator.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import SwiftUI
import Combine

/// Coordinates AI inference operations using individual components
@MainActor
public class AIInferenceCoordinator: ObservableObject, ModelInferenceProtocol {
    
    @Published public var isModelLoaded: Bool = false
    @Published public var loadingProgress: Float = 0.0
    @Published public var loadingStatus: String = "Ready"
    @Published public var lastError: String?
    
    public let modelLoader = ModelLoader()
    public let inferenceEngine = InferenceEngine()
    private let memoryManager = MemoryManager.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind model loader state to coordinator
        modelLoader.$isModelLoaded
            .assign(to: \.isModelLoaded, on: self)
            .store(in: &cancellables)
        
        modelLoader.$loadingProgress
            .assign(to: \.loadingProgress, on: self)
            .store(in: &cancellables)
        
        modelLoader.$loadingStatus
            .assign(to: \.loadingStatus, on: self)
            .store(in: &cancellables)
    }
    
    /// Load a model for inference
    public func loadModel(_ model: AIModel) async throws {
        do {
            try await modelLoader.loadModel(model)
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Unload the current model
    public func unloadModel() async {
        await modelLoader.unloadModel()
    }
    
    /// Generate text using the loaded model
    public func generateText(prompt: String, maxTokens: Int) async throws -> String {
        
        let container = modelLoader.getModelContainer()
        
        do {
            return try await inferenceEngine.generateText(
                prompt: prompt,
                modelContainer: container,
                maxTokens: maxTokens,
                temperature: 0.7
            )
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Generate streaming text
    public func generateStreamingText(prompt: String, maxTokens: Int) -> AsyncThrowingStream<StreamingResponse, Error> {
        
        let container = modelLoader.getModelContainer()
        
        return inferenceEngine.generateStreamingText(
            prompt: prompt,
            modelContainer: container,
            maxTokens: maxTokens,
            temperature: 0.7
        )
    }
    
    /// Switch to a different model
    public func switchModel(to model: AIModel) async throws {
        do {
            try await modelLoader.switchModel(to: model)
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }
    
    /// Get the currently loaded model
    public var currentModel: AIModel? {
        return modelLoader.currentModel
    }
    
    /// Estimate token count for text
    public func estimateTokenCount(for text: String) -> Int {
        let container = modelLoader.getModelContainer()
        return inferenceEngine.estimateTokenCount(for: text, modelContainer: container)
    }
    
    /// Check if MLX Swift is available
    public var isMLXSwiftAvailable: Bool {
        #if canImport(MLX)
        return true
        #else
        return false
        #endif
    }
}