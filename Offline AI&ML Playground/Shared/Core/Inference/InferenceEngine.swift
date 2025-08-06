//
//  InferenceEngine.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os
#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon
#endif


/// Handles text generation and inference operations
@MainActor
public class InferenceEngine: ObservableObject {
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "InferenceEngine")
    private let memoryManager = MemoryManager.shared
    
    /// Generate text using the loaded model
    internal func generateText(
        prompt: String,
        modelContainer: Any?,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        
        #if canImport(MLX)
        guard let container = modelContainer as? ModelContainer else {
            throw AIInferenceError.modelNotLoaded
        }
        #else
        throw AIInferenceError.configurationError("MLX framework not available")
        #endif
        
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIInferenceError.invalidInput("Prompt cannot be empty")
        }
        
        // Check memory pressure
        let pressure = await memoryManager.getMemoryPressure()
        if pressure > 0.9 {
            throw AIInferenceError.memoryPressure(pressure)
        }
        
        logger.info("Starting text generation with max tokens: \(maxTokens)")
        
        #if canImport(MLX)
        do {
            let result = try await container.perform { context in
                // Create user input
                let userInput = UserInput(prompt: prompt)
                
                // Prepare input using processor
                let input = try await context.processor.prepare(input: userInput)
                
                // Setup generation parameters
                let parameters = GenerateParameters(
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: 0.9
                )
                
                // Generate text using MLX
                var generatedText = ""
                let _ = try MLXLMCommon.generate(
                    input: input,
                    parameters: parameters,
                    context: context
                ) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    generatedText += text
                    return tokens.count >= maxTokens ? .stop : .more
                }
                
                return generatedText
            }
            
            logger.info("Text generation completed successfully")
            return result
            
        } catch {
            logger.error("Text generation failed: \(error)")
            throw AIInferenceError.generationFailed(error.localizedDescription)
        }
        #else
        throw AIInferenceError.configurationError("MLX framework not available")
        #endif
    }
    
    /// Generate streaming text output
    internal func generateStreamingText(
        prompt: String,
        modelContainer: Any?,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncThrowingStream<StreamingResponse, Error> {
        
        return AsyncThrowingStream { continuation in
            Task {
                #if canImport(MLX)
                guard let container = modelContainer as? ModelContainer else {
                    continuation.finish(throwing: AIInferenceError.modelNotLoaded)
                    return
                }
                #else
                continuation.finish(throwing: AIInferenceError.configurationError("MLX framework not available"))
                return
                #endif
                
                guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.finish(throwing: AIInferenceError.invalidInput("Prompt cannot be empty"))
                    return
                }
                
                #if canImport(MLX)
                do {
                    let metricsActor = MetricsActor()
                    
                    let _ = try await container.perform { context in
                        // Create user input
                        let userInput = UserInput(prompt: prompt)
                        
                        // Prepare input using processor
                        let input = try await context.processor.prepare(input: userInput)
                        
                        // Setup generation parameters
                        let parameters = GenerateParameters(
                            maxTokens: maxTokens,
                            temperature: temperature,
                            topP: 0.9
                        )
                        
                        // Generate text using MLX
                        var accumulatedText = ""
                        let _ = try MLXLMCommon.generate(
                            input: input,
                            parameters: parameters,
                            context: context
                        ) { tokens in
                            let text = context.tokenizer.decode(tokens: tokens)
                            
                            // Extract only the new part
                            let newText = String(text.dropFirst(accumulatedText.count))
                            accumulatedText = text
                            
                            // Update metrics
                            Task {
                                await metricsActor.update(tokenCount: tokens.count, currentTime: Date())
                            }
                            
                            let metrics = TokenMetrics()
                            let response = StreamingResponse(text: newText, metrics: metrics)
                            continuation.yield(response)
                            
                            return tokens.count >= maxTokens ? .stop : .more
                        }
                        
                        // Finalize metrics
                        await metricsActor.finalize()
                        let finalMetrics = await metricsActor.getMetrics()
                        
                        logger.info("Streaming generation completed. Tokens: \(finalMetrics.totalTokens), Speed: \(finalMetrics.averageTokensPerSecond) tok/s")
                        continuation.finish()
                    }
                    
                } catch {
                    logger.error("Streaming generation failed: \(error)")
                    continuation.finish(throwing: AIInferenceError.generationFailed(error.localizedDescription))
                }
                #else
                continuation.finish(throwing: AIInferenceError.configurationError("MLX framework not available"))
                #endif
            }
        }
    }
    
    /// Estimate token count for a prompt
    internal func estimateTokenCount(
        for text: String,
        modelContainer: Any?
    ) -> Int {
        #if canImport(MLX)
        guard modelContainer is ModelContainer else { return 0 }
        
        // For now, return an estimate since we can't do async in sync context
        // A more accurate count would require making this method async
        return text.split(separator: " ").count * 4 / 3
        #else
        // Rough estimation when MLX is not available
        return text.split(separator: " ").count * 4 / 3
        #endif
    }
}