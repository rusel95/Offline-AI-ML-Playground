//
//  UnifiedModelLoaderProtocol.swift
//  Offline AI&ML Playground
//
//  Created on 2025-01-08.
//

import Foundation

/// Protocol defining the interface for unified model loading implementations
/// Supports both MLX and Swift Transformers backends
protocol UnifiedModelLoaderProtocol {
    /// Name of the loader for identification
    var loaderName: String { get }
    
    /// Check if this loader can handle the specified model
    /// - Parameter model: The AIModel to check
    /// - Returns: True if this loader can handle the model
    func canLoad(model: AIModel) async -> Bool
    
    /// Load a model from the specified path
    /// - Parameters:
    ///   - model: The AIModel definition
    ///   - modelPath: Path to the model files
    /// - Returns: A loaded model instance (type-erased)
    /// - Throws: UnifiedModelLoadError if loading fails
    func loadModel(model: AIModel, modelPath: URL) async throws -> LoadedModel
    
    /// Generate text using the loaded model
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - model: The loaded model instance
    ///   - maxTokens: Maximum tokens to generate
    ///   - temperature: Sampling temperature
    /// - Returns: An async stream of generated text chunks
    func generateText(
        prompt: String,
        model: LoadedModel,
        maxTokens: Int,
        temperature: Float
    ) -> AsyncThrowingStream<String, Error>
    
    /// Unload the model and free resources
    /// - Parameter model: The model instance to unload
    func unloadModel(_ model: LoadedModel) async
    
    /// Get memory usage of the loaded model
    /// - Parameter model: The model instance
    /// - Returns: Memory usage in bytes, or nil if unavailable
    func getMemoryUsage(for model: LoadedModel) -> Int?
}

/// Wrapper for loaded models with metadata
struct LoadedModel {
    /// The actual model instance (MLX or Core ML)
    let model: Any
    
    /// The tokenizer instance if available
    let tokenizer: TokenizerProtocol?
    
    /// The loader that created this model
    let loaderName: String
    
    /// Model-specific configuration
    let configuration: [String: Any]
}

/// Protocol for tokenizer implementations
protocol TokenizerProtocol {
    /// Initialize tokenizer for the specified model
    /// - Parameter modelId: The model identifier
    /// - Throws: Error if tokenizer initialization fails
    func initialize(for modelId: String) async throws
    
    /// Apply chat template to messages
    /// - Parameter messages: Array of message dictionaries
    /// - Returns: Tokenized input string
    /// - Throws: Error if tokenization fails
    func applyChatTemplate(messages: [[String: String]]) throws -> String
    
    /// Encode text to tokens
    /// - Parameter text: The text to encode
    /// - Returns: Array of token IDs
    func encode(text: String) -> [Int]
    
    /// Decode tokens to text
    /// - Parameter tokens: Array of token IDs
    /// - Returns: Decoded text
    func decode(tokens: [Int]) -> String
    
    /// Check if tokenizer supports the model
    /// - Parameter modelId: The model identifier
    /// - Returns: True if supported
    func supports(modelId: String) -> Bool
}

/// Errors that can occur during unified model loading
enum UnifiedModelLoadError: LocalizedError {
    case unsupportedModel(String)
    case modelNotFound(URL)
    case loadingFailed(String)
    case tokenizerInitializationFailed(String)
    case incompatibleFormat(String)
    case missingConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedModel(let model):
            return "Model '\(model)' is not supported by any available loader"
        case .modelNotFound(let path):
            return "Model not found at path: \(path)"
        case .loadingFailed(let reason):
            return "Failed to load model: \(reason)"
        case .tokenizerInitializationFailed(let reason):
            return "Failed to initialize tokenizer: \(reason)"
        case .incompatibleFormat(let format):
            return "Incompatible model format: \(format)"
        case .missingConfiguration(let key):
            return "Missing required configuration: \(key)"
        }
    }
}

// Model format detection is handled by the existing ModelFormatDetector class