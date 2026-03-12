//
//  AIInferenceService.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 21.11.2025.
//

import Foundation

/// Protocol defining the interface for AI model inference services.
/// This allows switching between different backends (e.g., MLX, Transformers/CoreML).
@MainActor
protocol AIInferenceService: ObservableObject {
    
    /// Whether a model is currently loaded and ready for inference
    var isModelLoaded: Bool { get }
    
    /// Current loading progress (0.0 to 1.0)
    var loadingProgress: Float { get } // Changed to Float to match existing usage
    
    /// Current status message
    var loadingStatus: String { get }
    
    /// Last error message, if any
    var lastError: String? { get }
    
    /// Load a specific AI model
    /// - Parameter model: The model to load
    func loadModel(_ model: AIModel) async throws
    
    /// Generate text for a prompt
    /// - Parameters:
    ///   - prompt: Input text
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature
    /// - Returns: Generated text
    func generateText(prompt: String, maxTokens: Int, temperature: Float) async throws -> String
    
    /// Generate streaming text for a prompt
    /// - Parameters:
    ///   - prompt: Input text
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature
    /// - Returns: AsyncStream of text chunks
    func generateStreamingText(prompt: String, maxTokens: Int, temperature: Float) -> AsyncStream<String>
    
    /// Generate streaming text with metrics
    /// - Parameters:
    ///   - prompt: Input text
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature
    ///   - topP: Top-P sampling
    /// - Returns: AsyncStream of StreamingResponse (text + metrics)
    func generateStreamingTextWithMetrics(prompt: String, maxTokens: Int, temperature: Float, topP: Float) -> AsyncStream<StreamingResponse>
    
    /// Unload the current model to free memory
    func unloadModel() async
}
