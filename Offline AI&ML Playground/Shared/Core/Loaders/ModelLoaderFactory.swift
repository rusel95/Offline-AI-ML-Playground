//
//  ModelLoaderFactory.swift
//  Offline AI&ML Playground
//
//  Created on 2025-01-08.
//

import Foundation

/// Factory class to determine which model loader to use
@MainActor
class ModelLoaderFactory {
    
    static let shared = ModelLoaderFactory()
    
    private init() {}
    
    /// Available loaders
    private lazy var loaders: [UnifiedModelLoaderProtocol] = [
        MLXUnifiedModelLoader()
        // Future: Add more loaders here (e.g., CoreMLLoader, PureSwiftTransformersLoader)
    ]
    
    /// Get the best loader for a given model
    /// - Parameter model: The AIModel to load
    /// - Returns: The most suitable loader, or nil if no loader supports the model
    func getLoader(for model: AIModel) async -> UnifiedModelLoaderProtocol? {
        print("🏭 Finding best loader for: \(model.name)")
        
        // Check each loader in priority order
        for loader in loaders {
            if await loader.canLoad(model: model) {
                print("✅ Selected loader: \(loader.loaderName)")
                return loader
            }
        }
        
        print("❌ No suitable loader found for: \(model.name)")
        return nil
    }
    
    /// Get loader information for a model without loading it
    /// - Parameter model: The AIModel to check
    /// - Returns: Information about which loader would be used
    func getLoaderInfo(for model: AIModel) async -> LoaderInfo {
        if let loader = await getLoader(for: model) {
            // Check tokenizer support
            let tokenizer = SimplifiedSwiftTransformersTokenizer()
            let hasSwiftTransformersSupport = tokenizer.supports(modelId: model.huggingFaceRepo)
            
            return LoaderInfo(
                loaderName: loader.loaderName,
                supportsModel: true,
                tokenizerType: hasSwiftTransformersSupport ? .swiftTransformers : .mlxBuiltin,
                inferenceEngine: .mlx
            )
        } else {
            return LoaderInfo(
                loaderName: "None",
                supportsModel: false,
                tokenizerType: .none,
                inferenceEngine: .none
            )
        }
    }
}

/// Information about loader capabilities
struct LoaderInfo {
    let loaderName: String
    let supportsModel: Bool
    let tokenizerType: TokenizerType
    let inferenceEngine: InferenceEngineType
    
    var description: String {
        if !supportsModel {
            return "Model not supported"
        }
        
        return "\(tokenizerType.displayName) + \(inferenceEngine.displayName)"
    }
}

/// Types of tokenizers available
enum TokenizerType {
    case swiftTransformers
    case mlxBuiltin
    case none
    
    var displayName: String {
        switch self {
        case .swiftTransformers:
            return "Swift Transformers"
        case .mlxBuiltin:
            return "MLX Tokenizer"
        case .none:
            return "No Tokenizer"
        }
    }
}

/// Types of inference engines available
enum InferenceEngineType {
    case mlx
    case coreML
    case none
    
    var displayName: String {
        switch self {
        case .mlx:
            return "MLX Swift"
        case .coreML:
            return "Core ML"
        case .none:
            return "No Engine"
        }
    }
}