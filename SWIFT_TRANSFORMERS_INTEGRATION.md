# Integration of Hugging Face Swift Transformers

## Overview
The goal is to integrate `huggingface/swift-transformers` to provide a "transformers-like" API for on-device inference, potentially replacing or augmenting the current MLX-based implementation.

## Current State
- **Engine**: MLX (via `mlx-swift`, `MLXLLM`, `MLXLMCommon`).
- **Manager**: `AIInferenceManager` handles model loading, memory management, and inference.
- **Flow**:
    1.  Check model format (MLX, GGUF, etc.).
    2.  Load `ModelContainer` via `LLMModelFactory`.
    3.  Generate text using `MLXLMCommon.generate`.

## Proposed Solution: Swift Transformers
The `huggingface/swift-transformers` package provides a Swift implementation of the Transformers API, focusing on CoreML and generic Swift execution.

### Benefits
- **Standard API**: Familiar `AutoModel`, `AutoTokenizer` pattern.
- **CoreML Support**: Native support for CoreML models, which can be highly optimized for Neural Engine (ANE).
- **Ecosystem**: Direct integration with Hugging Face Hub for `ml-package` (CoreML) models.

### Implementation Plan

1.  **Add Dependency**:
    Add `https://github.com/huggingface/swift-transformers` to the project dependencies.

2.  **Create `TransformersInferenceManager`**:
    A new manager class that implements the inference logic using `swift-transformers`.

3.  **Unified Interface**:
    Refactor `ChatViewModel` to use a protocol `InferenceEngine` so we can switch between `MLX` and `Transformers` backends.

### Code Structure

#### 1. Inference Protocol
```swift
protocol InferenceEngine: Actor {
    var isModelLoaded: Bool { get }
    func loadModel(_ model: AIModel) async throws
    func generateStreamingText(prompt: String, maxTokens: Int, temperature: Float) -> AsyncStream<String>
    func unloadModel() async
}
```

#### 2. Transformers Implementation
```swift
import Transformers

actor TransformersInferenceManager: InferenceEngine {
    private var model: LanguageModel?
    private var tokenizer: Tokenizer?
    
    func loadModel(_ model: AIModel) async throws {
        // Load using AutoModel.from(pretrained: ...)
        // Note: Requires CoreML converted models or compatible architecture
    }
    
    // ... implementation
}
```

## Considerations
- **Model Compatibility**: `swift-transformers` works best with CoreML models (often ending in `.mlpackage`). The current project downloads `.safetensors` (MLX) and `.gguf`. We might need to download different model versions (CoreML versions) for this new backend.
- **Performance**: MLX is generally faster for LLMs on Apple Silicon than generic Swift, but CoreML (via `swift-transformers`) can be very efficient if the model is properly converted.

## Next Steps
1.  Create `TransformersInferenceManager.swift` in `Offline AI&ML Playground/Shared/Core/Inference/`.
2.  Demonstrate how to use `AutoModel` and `AutoTokenizer`.
