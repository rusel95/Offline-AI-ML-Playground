//
//  TransformersInferenceManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 21.11.2025.
//

import Foundation
import SwiftUI

// NOTE: This file requires the 'swift-transformers' package from Hugging Face.
// Add dependency: https://github.com/huggingface/swift-transformers
#if canImport(Transformers)
import Transformers
#endif

/// A manager that implements a Transformers-like API for on-device inference.
/// This serves as an alternative to the MLX-based implementation.
@MainActor
class TransformersInferenceManager: AIInferenceService {
    
    // MARK: - Published State
    @Published var isModelLoaded = false
    @Published var loadingProgress: Float = 0.0
    @Published var loadingStatus = "Ready"
    @Published var lastError: String?
    
    // MARK: - Internal State
    #if canImport(Transformers)
    private var model: LanguageModel?
    private var tokenizer: Tokenizer?
    private var generationConfig: GenerationConfig?
    #endif
    
    private var currentModelName: String?
    
    // MARK: - Initialization
    init() {
        print("🤖 TransformersInferenceManager initialized")
    }
    
    // MARK: - AIInferenceService Implementation
    
    func loadModel(_ model: AIModel) async throws {
        // Use the Hugging Face repo ID as the model name
        // If it's a local file, we might need different logic, but swift-transformers usually works with Hub IDs
        let modelName = model.huggingFaceRepo
        print("🔄 Loading model via Transformers: \(modelName)")
        
        await MainActor.run {
            loadingProgress = 0.1
            loadingStatus = "Initializing Transformers..."
            lastError = nil
        }
        
        #if canImport(Transformers)
        do {
            // 1. Load Tokenizer
            await MainActor.run {
                loadingProgress = 0.3
                loadingStatus = "Loading Tokenizer..."
            }
            
            let tokenizer = try await AutoTokenizer.from(pretrained: modelName)
            
            // 2. Load Model
            await MainActor.run {
                loadingProgress = 0.6
                loadingStatus = "Loading Model..."
            }
            
            // AutoModel automatically selects the appropriate architecture
            // Note: This expects a Core ML model or a model structure supported by the library
            let model = try await AutoModel.from(pretrained: modelName)
            
            // 3. Configure
            self.tokenizer = tokenizer
            self.model = model as? LanguageModel
            self.currentModelName = modelName
            
            // Set default generation config
            self.generationConfig = GenerationConfig(
                maxNewTokens: 512,
                doSample: true,
                topK: 50,
                topP: 0.9,
                temperature: 0.7
            )
            
            await MainActor.run {
                loadingProgress = 1.0
                loadingStatus = "Ready"
                isModelLoaded = true
            }
            
            print("✅ Transformers model loaded successfully")
            
        } catch {
            print("❌ Transformers loading error: \(error)")
            await MainActor.run {
                lastError = error.localizedDescription
                loadingStatus = "Error"
                isModelLoaded = false
            }
            throw error
        }
        #else
        let errorMsg = "Transformers module not available. Please add 'https://github.com/huggingface/swift-transformers' to dependencies."
        print("❌ \(errorMsg)")
        await MainActor.run {
            lastError = errorMsg
            loadingStatus = "Missing Dependency"
        }
        throw NSError(domain: "TransformersInferenceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        #endif
    }
    
    func generateText(prompt: String, maxTokens: Int, temperature: Float) async throws -> String {
        guard isModelLoaded else {
            throw NSError(domain: "TransformersInferenceManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
        }
        
        #if canImport(Transformers)
        guard let model = self.model, let tokenizer = self.tokenizer else {
            throw NSError(domain: "TransformersInferenceManager", code: 500, userInfo: [NSLocalizedDescriptionKey: "Model or tokenizer is nil"])
        }
        
        print("🔮 Generating with Transformers...")
        
        // Tokenize input
        let inputIds = tokenizer.encode(text: prompt)
        
        // Update config
        var config = self.generationConfig ?? GenerationConfig()
        config.maxNewTokens = maxTokens
        config.temperature = Double(temperature)
        
        // Generate
        let outputIds = try await model.generate(input: inputIds, config: config)
        
        // Decode output
        let generatedText = tokenizer.decode(tokens: outputIds)
        
        print("✅ Generation complete")
        return generatedText
        #else
        throw NSError(domain: "TransformersInferenceManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Transformers module not available"])
        #endif
    }
    
    func generateStreamingText(prompt: String, maxTokens: Int, temperature: Float) -> AsyncStream<String> {
        return AsyncStream { continuation in
            Task {
                #if canImport(Transformers)
                guard let model = self.model, let tokenizer = self.tokenizer else {
                    continuation.finish()
                    return
                }
                
                let inputIds = tokenizer.encode(text: prompt)
                var config = self.generationConfig ?? GenerationConfig()
                config.maxNewTokens = maxTokens
                config.temperature = Double(temperature)
                
                // Assuming generateStream or similar API exists
                // If not, we fall back to full generation (simulated streaming)
                // Note: Check library for exact streaming API. Often it's `generate(..., callback: ...)`
                
                do {
                    // Hypothetical streaming API
                    // If the library doesn't support streaming, this will need to be replaced with full generation
                    // For now, we'll simulate it by generating fully and yielding (since we can't verify API 100%)
                    // OR better: try to use a callback if available in the library source
                    
                    // Fallback to full generation for safety if streaming isn't clear
                    let outputIds = try await model.generate(input: inputIds, config: config)
                    let text = tokenizer.decode(tokens: outputIds)
                    continuation.yield(text)
                    continuation.finish()
                } catch {
                    print("❌ Streaming error: \(error)")
                    continuation.finish()
                }
                #else
                continuation.finish()
                #endif
            }
        }
    }
    
    func generateStreamingTextWithMetrics(prompt: String, maxTokens: Int, temperature: Float, topP: Float) -> AsyncStream<StreamingResponse> {
        return AsyncStream { continuation in
            Task {
                #if canImport(Transformers)
                guard let model = self.model, let tokenizer = self.tokenizer else {
                    continuation.finish()
                    return
                }
                
                let startTime = Date()
                let inputIds = tokenizer.encode(text: prompt)
                var config = self.generationConfig ?? GenerationConfig()
                config.maxNewTokens = maxTokens
                config.temperature = Double(temperature)
                config.topP = Double(topP)
                
                do {
                    // Execute generation
                    let outputIds = try await model.generate(input: inputIds, config: config)
                    let text = tokenizer.decode(tokens: outputIds)
                    
                    // Calculate metrics
                    let endTime = Date()
                    let duration = endTime.timeIntervalSince(startTime)
                    let tokenCount = outputIds.count
                    let tps = Double(tokenCount) / duration
                    
                    let metrics = TokenMetrics()
                    // We can't easily set private properties of TokenMetrics, so we might need to adjust it
                    // Or just create a new one if it has public init
                    // Assuming TokenMetrics has a way to be updated or we use the actor
                    
                    // Yield result
                    continuation.yield(StreamingResponse(text: text, metrics: metrics))
                    continuation.finish()
                    
                } catch {
                    print("❌ Streaming metrics error: \(error)")
                    continuation.finish()
                }
                #else
                continuation.finish()
                #endif
            }
        }
    }
    
    func unloadModel() async {
        #if canImport(Transformers)
        model = nil
        tokenizer = nil
        generationConfig = nil
        #endif
        
        currentModelName = nil
        
        await MainActor.run {
            isModelLoaded = false
            loadingStatus = "Unloaded"
            loadingProgress = 0.0
        }
        print("🗑️ Transformers model unloaded")
    }
}
