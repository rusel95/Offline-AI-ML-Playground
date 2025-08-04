//
//  ModelLoader.swift
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
#if canImport(Hub)
import Hub
#endif

#if canImport(MLX)
typealias ModelContainer = MLXLMCommon.ModelContainer
typealias ModelConfiguration = MLXLMCommon.ModelConfiguration
#endif

/// Handles model loading and unloading operations
@MainActor
public class ModelLoader: ObservableObject {
    
    @Published public private(set) var isModelLoaded = false
    @Published public private(set) var loadingProgress: Float = 0.0
    @Published public private(set) var loadingStatus = "Ready"
    @Published public private(set) var currentModel: AIModel?
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "ModelLoader")
    private let memoryManager = MemoryManager.shared
    private let fileManager = ModelFileManager.shared
    
    private var modelContainer: ModelContainer?
    private var modelConfiguration: ModelConfiguration?
    private var isCurrentlyLoading = false
    
    /// Load a model with memory checks
    public func loadModel(_ model: AIModel) async throws {
        guard !isCurrentlyLoading else {
            throw ModelError.loadingError("Another model is currently loading")
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        // Memory check
        let requiredMemoryGB = getRequiredMemory(for: model)
        guard await memoryManager.hasAvailableMemory(requiredGB: requiredMemoryGB) else {
            throw ModelError.memoryError("Insufficient memory. Required: \(requiredMemoryGB)GB")
        }
        
        // Validate model files exist
        guard fileManager.isModelDownloaded(model.id) else {
            throw ModelError.fileSystemError("Model files not found")
        }
        
        updateLoadingStatus("Loading \(model.name)...")
        
        do {
            // Create model configuration
            let config = try createModelConfiguration(for: model)
            self.modelConfiguration = config
            
            // Load the model
            updateLoadingStatus("Initializing model...")
            updateLoadingProgress(0.3)
            
            #if canImport(MLX)
            // Create a local Hub instance
            let hub = HubApi()
            
            let container = try await LLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: config
            ) { progress in
                Task { @MainActor in
                    self.updateLoadingProgress(Float(progress.fractionCompleted))
                }
            }
            self.modelContainer = container
            #endif
            
            updateLoadingProgress(0.8)
            updateLoadingStatus("Model loaded successfully")
            
            self.currentModel = model
            self.isModelLoaded = true
            updateLoadingProgress(1.0)
            
            logger.info("Successfully loaded model: \(model.name)")
            
        } catch {
            updateLoadingStatus("Failed to load model")
            updateLoadingProgress(0.0)
            throw ModelError.loadingError(error.localizedDescription)
        }
    }
    
    /// Unload the current model
    public func unloadModel() async {
        guard isModelLoaded else { return }
        
        logger.info("Unloading current model")
        updateLoadingStatus("Unloading model...")
        
        #if canImport(MLX)
        modelContainer = nil
        #endif
        modelConfiguration = nil
        currentModel = nil
        isModelLoaded = false
        
        // Trigger memory cleanup
        await memoryManager.performDeepMemoryCleanup()
        
        updateLoadingStatus("Ready")
        updateLoadingProgress(0.0)
    }
    
    /// Switch to a different model
    public func switchModel(to model: AIModel) async throws {
        if currentModel?.id == model.id {
            logger.info("Model already loaded: \(model.name)")
            return
        }
        
        await unloadModel()
        try await loadModel(model)
    }
    
    /// Get the loaded model container for inference
    func getModelContainer() -> Any? {
        #if canImport(MLX)
        return modelContainer
        #else
        return nil
        #endif
    }
    
    // MARK: - Private Methods
    
    private func createModelConfiguration(for model: AIModel) throws -> ModelConfiguration {
        #if canImport(MLX)
        // For MLX models, use the repository ID directly
        // MLX Swift will handle the loading from the correct location
        return ModelConfiguration(id: model.huggingFaceRepo)
        #else
        throw ModelError.configurationError("MLX framework not available")
        #endif
    }
    
    private func getRequiredMemory(for model: AIModel) -> Double {
        // Estimate based on model size
        let modelSizeGB = Double(model.sizeInBytes) / 1_073_741_824.0
        return modelSizeGB * 1.5 // Add 50% buffer for runtime memory
    }
    
    private func updateLoadingStatus(_ status: String) {
        Task { @MainActor in
            self.loadingStatus = status
        }
    }
    
    private func updateLoadingProgress(_ progress: Float) {
        Task { @MainActor in
            self.loadingProgress = progress
        }
    }
}