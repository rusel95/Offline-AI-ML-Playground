//
//  MLXUnifiedModelLoader.swift
//  Offline AI&ML Playground
//
//  Created on 2025-01-08.
//

import Foundation
#if canImport(MLX)
import MLX
import MLXLLM
import MLXLMCommon
#endif

/// MLX model loader with Swift Transformers tokenizer support
class MLXUnifiedModelLoader: UnifiedModelLoaderProtocol {
    
    let loaderName = "MLX + Swift Transformers"
    
    private var modelContainer: ModelContainer?
    private var swiftTransformersTokenizer: SimplifiedSwiftTransformersTokenizer?
    
    func canLoad(model: AIModel) async -> Bool {
        // MLX can load most models, check for specific formats
        // Just check format, path check happens later
        let format = ModelFormatDetector.detectFormat(from: model.huggingFaceRepo, modelInfo: model)
        
        switch format {
        case .mlxSafetensors, .multiPartSafetensors:
            return true
        case .gguf:
            // GGUF requires special handling
            return model.filename.hasSuffix(".gguf")
        case .unknown:
            return false
        }
    }
    
    func loadModel(model: AIModel, modelPath: URL) async throws -> LoadedModel {
        print("🔧 Loading model with MLX + Swift Transformers: \(model.name)")
        
        // Try to initialize Swift Transformers tokenizer
        let tokenizer = await initializeTokenizer(for: model)
        
        // Load the MLX model
        let mlxModel = try await loadMLXModel(model: model, modelPath: modelPath)
        
        // Create configuration
        var configuration: [String: Any] = [
            "modelId": model.id,
            "modelName": model.name,
            "format": (model.filename as NSString).pathExtension
        ]
        
        if tokenizer != nil {
            configuration["tokenizerType"] = "SwiftTransformers"
            print("✅ Using Swift Transformers tokenizer")
        } else {
            configuration["tokenizerType"] = "MLX"
            print("ℹ️ Using MLX built-in tokenizer")
        }
        
        return LoadedModel(
            model: mlxModel,
            tokenizer: tokenizer,
            loaderName: loaderName,
            configuration: configuration
        )
    }
    
    func generateText(
        prompt: String,
        model: LoadedModel,
        maxTokens: Int,
        temperature: Float
    ) -> AsyncThrowingStream<String, Error> {
        #if canImport(MLX)
        guard let modelContainer = model.model as? ModelContainer else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: UnifiedModelLoadError.loadingFailed("Invalid model type"))
            }
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // Format prompt using tokenizer if available
                    let formattedPrompt: String
                    if let tokenizer = model.tokenizer {
                        // Use Swift Transformers tokenizer for chat template
                        let messages = [["role": "user", "content": prompt]]
                        formattedPrompt = try tokenizer.applyChatTemplate(messages: messages)
                        print("📝 Using Swift Transformers formatted prompt")
                    } else {
                        // Use default formatting
                        formattedPrompt = prompt
                        print("📝 Using default prompt formatting")
                    }
                    
                    // Generate text using MLX
                    let result = try await modelContainer.perform { [formattedPrompt, maxTokens, temperature] context in
                        let input = try await context.processor.prepare(input: .init(prompt: formattedPrompt))
                        
                        return try MLXLMCommon.generate(
                            input: input,
                            parameters: .init(
                                maxTokens: maxTokens,
                                temperature: temperature,
                                topP: 0.95
                            ),
                            context: context
                        ) { tokens in
                            // Stream tokens as they are generated
                            if tokens.count % 4 == 0 {
                                let text = context.tokenizer.decode(tokens: tokens)
                                DispatchQueue.main.async {
                                    continuation.yield(text)
                                }
                            }
                            return .more
                        }
                    }
                    
                    // Send final result
                    let finalText = result.output
                    continuation.yield(finalText)
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        #else
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: UnifiedModelLoadError.loadingFailed("MLX not available"))
        }
        #endif
    }
    
    func unloadModel(_ model: LoadedModel) async {
        // Clear MLX model
        modelContainer = nil
        
        // Clear tokenizer
        swiftTransformersTokenizer = nil
        
        // Force memory cleanup
        #if canImport(MLX)
        await MemoryManager.shared.performDeepMemoryCleanup()
        #endif
        
        print("♻️ Model unloaded and memory cleaned up")
    }
    
    func getMemoryUsage(for model: LoadedModel) -> Int? {
        // Use async context properly
        return nil // For now, return nil until we can properly implement async memory check
    }
    
    // MARK: - Private Helpers
    
    private func initializeTokenizer(for model: AIModel) async -> TokenizerProtocol? {
        let tokenizer = SimplifiedSwiftTransformersTokenizer()
        
        // Check if Swift Transformers supports this model
        guard tokenizer.supports(modelId: model.huggingFaceRepo) else {
            print("ℹ️ Swift Transformers doesn't support \(model.huggingFaceRepo), using MLX tokenizer")
            return nil
        }
        
        do {
            try await tokenizer.initialize(for: model.huggingFaceRepo)
            self.swiftTransformersTokenizer = tokenizer
            return tokenizer
        } catch {
            print("⚠️ Swift Transformers tokenizer initialization failed: \(error)")
            return nil
        }
    }
    
    private func loadMLXModel(model: AIModel, modelPath: URL) async throws -> ModelContainer {
        #if canImport(MLX)
        // Create MLX configuration
        let configuration = createMLXConfiguration(for: model)
        
        // Load model using MLX
        print("🔧 Loading model with configuration: \(configuration)")
        
        // Load the model using LLMModelFactory
        let modelContainer = try await LLMModelFactory.shared.loadContainer(
            configuration: configuration,
            progressHandler: { progress in
                print("Loading progress: \(progress.fractionCompleted)")
            }
        )
        
        self.modelContainer = modelContainer
        print("✅ MLX model loaded successfully")
        return modelContainer
        #else
        throw UnifiedModelLoadError.loadingFailed("MLX not available")
        #endif
    }
    
    private func createMLXConfiguration(for model: AIModel) -> ModelConfiguration {
        #if canImport(MLX)
        // Use the HuggingFace repository ID for MLX to handle conversions
        let modelRepo = model.huggingFaceRepo
        print("📋 Creating MLX configuration for: \(modelRepo)")
        
        return ModelConfiguration(id: modelRepo)
        #else
        // Return a dummy configuration
        return ModelConfiguration(id: model.huggingFaceRepo)
        #endif
    }
}