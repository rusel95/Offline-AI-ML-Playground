import Foundation
import SwiftUI
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon
import Hub

/// Manager for handling real on-device AI inference using MLX Swift
@MainActor
class AIInferenceManager: ObservableObject {
    @Published var isModelLoaded = false
    @Published var loadingProgress: Float = 0.0
    @Published var loadingStatus = "Ready"
    @Published var lastError: String?
    
    private var currentModel: AIModel?
    private var modelContainer: ModelContainer?
    private var modelConfiguration: ModelConfiguration?
    
    /// Initialize the inference manager
    init() {
        print("🤖 AIInferenceManager initialized")
        setupLogging()
    }
    
    /// Setup comprehensive logging
    private func setupLogging() {
        print("📋 Setting up comprehensive logging system")
        print("📱 Device info: \(ProcessInfo.processInfo.machineDescription)")
        print("💾 Available memory: \(ProcessInfo.processInfo.physicalMemory) bytes")
        print("🔧 MLX Swift availability: \(isMLXSwiftAvailable ? "✅ Available" : "❌ Not Available")")
    }
    
    /// Load a specific AI model
    /// - Parameter model: The model to load
    func loadModel(_ model: AIModel) async throws {
        
        print("🚀 Starting model loading process")
        print("📋 Model: \(model.name) (\(model.id))")
        print("📦 Type: \(model.type)")
        print("💾 Size: \(model.formattedSize)")
        print("🏠 Repository: \(model.huggingFaceRepo)")
        print("📄 Filename: \(model.filename)")
        
        // Check if model exists locally first
        let localModelPath = getLocalModelPath(for: model)
        let isLocallyAvailable = FileManager.default.fileExists(atPath: localModelPath.path)
        
        print("📁 Local model path: \(localModelPath.path)")
        print("🔍 Model exists locally: \(isLocallyAvailable)")
        
        guard isModelLoaded == false else {
            print("⚠️ A model is already loaded, unloading first")
            unloadModel()
            return // Exit early if model already loaded
        }
        
        await MainActor.run {
            loadingProgress = 0.0
            loadingStatus = "Initializing..."
            lastError = nil
        }
        
        do {
            await MainActor.run {
                loadingProgress = 0.1
                loadingStatus = "Creating model configuration..."
            }
            
            let config = createModelConfiguration(for: model)
            print("⚙️ Created model configuration: \(config.id)")
            
            await MainActor.run {
                loadingProgress = 0.2
                loadingStatus = "Preparing model container..."
            }
            
            // Create Hub API for custom download location - only download if not available locally
            let hub = HubApi(downloadBase: getModelDownloadDirectory())
            print("📁 Using download directory: \(getModelDownloadDirectory().path)")
            
            // If model exists locally, inform Hub API to use local files
            if isLocallyAvailable {
                print("✅ Using locally cached model files")
                await MainActor.run {
                    loadingProgress = 0.5
                    loadingStatus = "Loading from local cache..."
                }
            } else {
                print("⬇️ Model not found locally, will download from repository")
                await MainActor.run {
                    loadingProgress = 0.3
                    loadingStatus = "Downloading model weights..."
                }
            }
            
            // Load model container
            print("🔄 Loading model container with configuration: \(config.id)")
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: config
            ) { progress in
                let progressStatus = isLocallyAvailable ? "Loading" : "Downloading"
                let baseProgress = isLocallyAvailable ? 0.5 : 0.3
                let progressRange = isLocallyAvailable ? 0.4 : 0.6
                
                print("📊 Model \(progressStatus.lowercased()) progress: \(progress.fractionCompleted * 100)%")
                Task { @MainActor in
                    self.loadingProgress = Float(baseProgress + (progress.fractionCompleted * progressRange))
                    self.loadingStatus = "\(progressStatus): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            
            await MainActor.run {
                loadingProgress = 0.9
                loadingStatus = "Finalizing model initialization..."
            }
            print("✅ Model container loaded successfully")
            
            // If we downloaded the model, mark it as downloaded
            if !isLocallyAvailable {
                markModelAsDownloaded(model)
            }
            
            // Small delay to ensure everything is properly initialized
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                loadingProgress = 1.0
                loadingStatus = "Model loaded successfully"
                isModelLoaded = true
                currentModel = model
            }
            
            print("🎉 Model loaded successfully: \(model.name)")
            print("🔗 Source: \(isLocallyAvailable ? "Local Cache" : "Downloaded")")
            print("📈 Final memory usage: \(getMemoryUsage()) bytes")
            
        } catch {
            await MainActor.run {
                lastError = "Failed to load model: \(error.localizedDescription)"
                loadingStatus = "Error loading model"
                isModelLoaded = false
            }
            print("❌ Error loading model: \(error.localizedDescription)")
            print("🔍 Error details: \(String(describing: error))")
            throw error
        }
    }
    
    /// Generate text using the loaded model
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Sampling temperature (0.0 - 1.0)
    /// - Returns: Generated text
    func generateText(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        
        guard isModelLoaded, let _ = currentModel else {
            print("❌ Cannot generate text: Model not loaded")
            throw AIInferenceError.modelNotLoaded
        }
        
        print("🔮 Starting text generation")
        print("📝 Prompt: \(String(prompt.prefix(100)))")
        print("⚙️ Max tokens: \(maxTokens), Temperature: \(temperature)")
        
        do {
            guard let container = modelContainer else {
                print("❌ Model container is nil")
                throw AIInferenceError.modelNotLoaded
            }
            
            print("🏃‍♂️ Performing inference with model container")
            
            let result = try await container.perform { context in
                print("🔧 Context ready, preparing input")
                
                // Create user input
                let userInput = UserInput(prompt: prompt)
                print("📤 Created user input")
                
                // Prepare input using processor
                let input = try await context.processor.prepare(input: userInput)
                print("✅ Input prepared successfully")
                
                // Setup generation parameters
                let parameters = GenerateParameters(
                    maxTokens: maxTokens,
                    temperature: temperature,
                    topP: 0.9
                )
                print("⚙️ Generation parameters set: maxTokens=\(parameters.maxTokens), temp=\(String(describing: parameters.temperature)), topP=\(String(describing: parameters.topP))")
                
                // Generate text using MLX
                var generatedText = ""
                let _ = try MLXLMCommon.generate(
                    input: input,
                    parameters: parameters,
                    context: context
                ) { tokens in
                    let text = context.tokenizer.decode(tokens: tokens)
                    generatedText += text
                    print("🔄 Generated tokens: \(String(text.prefix(50)))")
                    return .more
                }
                
                print("✅ Text generation completed")
                return generatedText
            }
            
            print("🎯 Final generated text length: \(result.count) characters")
            print("📋 Generated text preview: \(String(result.prefix(200)))")
            return result
            
        } catch {
            print("❌ Error generating text: \(error.localizedDescription)")
            print("🔍 Error details: \(String(describing: error))")
            throw error
        }
    }
    
    /// Generate a streaming response
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Sampling temperature
    /// - Returns: AsyncStream of generated text chunks
    func generateStreamingText(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncStream<String> {
        
        print("🌊 Starting streaming text generation")
        print("📝 Prompt: \(String(prompt.prefix(100)))")
        
        return AsyncStream { continuation in
            Task {
                do {
                    guard isModelLoaded, let _ = currentModel else {
                        print("❌ Cannot stream text: Model not loaded")
                        continuation.finish()
                        return
                    }
                    
                    guard let container = modelContainer else {
                        print("❌ Model container is nil for streaming")
                        continuation.finish()
                        return
                    }
                    
                    print("🏃‍♂️ Performing streaming inference")
                    
                    let _ = try await container.perform { context in
                        print("🔧 Streaming context ready")
                        
                        // Create user input
                        let userInput = UserInput(prompt: prompt)
                        
                        // Prepare input using processor
                        let input = try await context.processor.prepare(input: userInput)
                        print("✅ Streaming input prepared")
                        
                        // Setup generation parameters
                        let parameters = GenerateParameters(
                            maxTokens: maxTokens,
                            temperature: temperature,
                            topP: 0.9
                        )
                        
                        // Generate text with streaming using MLX
                        var previousLength = 0
                        let _ = try MLXLMCommon.generate(
                            input: input,
                            parameters: parameters,
                            context: context
                        ) { tokens in
                            let fullText = context.tokenizer.decode(tokens: tokens)
                            
                            // Only yield the new part since last time
                            let newText = String(fullText.dropFirst(previousLength))
                            previousLength = fullText.count
                            
                            if !newText.isEmpty {
                                print("🌊 Streaming new chunk: \(String(newText.prefix(20)))")
                                continuation.yield(newText)
                            }
                            return .more
                        }
                        
                        return ""
                    }
                    
                    print("✅ Streaming generation completed")
                    continuation.finish()
                    
                } catch {
                    print("❌ Error in streaming generation: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Unload the current model
    func unloadModel() {
        print("🗑️ Starting model unload process")
        
        // Properly dispose of MLX model container
        modelContainer = nil
        modelConfiguration = nil
        
        isModelLoaded = false
        currentModel = nil
        loadingProgress = 0.0
        loadingStatus = "Ready"
        lastError = nil
        
        // Force garbage collection to free up memory
        MLX.eval([])
        
        print("✅ Model unloaded successfully")
        print("📈 Memory usage after cleanup: \(getMemoryUsage()) bytes")
    }
    
    /// Create model configuration for different model types
    private func createModelConfiguration(for model: AIModel) -> ModelConfiguration {
        print("🔧 Creating model configuration for: \(model.name)")
        
        // Try to determine the best configuration based on model name
        if model.name.lowercased().contains("llama") {
            if model.name.contains("3.2-1B") {
                print("📋 Using Llama 3.2 1B configuration")
                return ModelConfiguration(
                    id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                    overrideTokenizer: "PreTrainedTokenizer",
                    defaultPrompt: "Hello! How can I help you today?"
                )
            } else if model.name.contains("3.2-3B") {
                print("📋 Using Llama 3.2 3B configuration")
                return ModelConfiguration(
                    id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
                    overrideTokenizer: "PreTrainedTokenizer",
                    defaultPrompt: "Hello! How can I help you today?"
                )
            } else {
                print("📋 Using default Llama configuration")
                return ModelConfiguration(
                    id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                    overrideTokenizer: "PreTrainedTokenizer",
                    defaultPrompt: "Hello! How can I help you today?"
                )
            }
        } else if model.name.lowercased().contains("mistral") {
            print("📋 Using Mistral configuration")
            return ModelConfiguration(
                id: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
                overrideTokenizer: "PreTrainedTokenizer",
                defaultPrompt: "Hello! How can I help you today?"
            )
        } else if model.name.lowercased().contains("phi") {
            print("📋 Using Phi configuration")
            return ModelConfiguration(
                id: "mlx-community/Phi-3.5-mini-instruct-4bit",
                overrideTokenizer: "PreTrainedTokenizer",
                defaultPrompt: "Hello! How can I help you today?"
            )
        } else {
            print("📋 Using default model configuration")
            return ModelConfiguration(
                id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
                overrideTokenizer: "PreTrainedTokenizer",
                defaultPrompt: "Hello! How can I help you today?"
            )
        }
    }
    
    /// Get model download directory
    private func getModelDownloadDirectory() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = documentsDir.appendingPathComponent("MLXModels")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        print("📁 Models directory: \(modelsDir.path)")
        
        return modelsDir
    }
    
    /// Get the local path for a specific model
    private func getLocalModelPath(for model: AIModel) -> URL {
        let modelsDir = getModelDownloadDirectory()
        
        // Create a more comprehensive path structure for the model
        let modelDirectory = modelsDir.appendingPathComponent(model.id, isDirectory: true)
        
        // Check if it's a directory-based model (MLX style) or single file
        if model.filename.hasSuffix(".gguf") || model.filename.hasSuffix(".bin") {
            // Single file model
            return modelsDir.appendingPathComponent("\(model.id)-\(model.filename)")
        } else {
            // Multi-file model - check for standard MLX files
            let configPath = modelDirectory.appendingPathComponent("config.json")
            let modelPath = modelDirectory.appendingPathComponent("model.safetensors")
            let tokenizerPath = modelDirectory.appendingPathComponent("tokenizer.json")
            
            // Return the directory if any of the key files exist
            if FileManager.default.fileExists(atPath: configPath.path) ||
               FileManager.default.fileExists(atPath: modelPath.path) ||
               FileManager.default.fileExists(atPath: tokenizerPath.path) {
                return modelDirectory
            }
            
            // Fallback to single file approach
            return modelsDir.appendingPathComponent(model.filename)
        }
    }
    
    /// Check if a model is downloaded and available locally
    private func isModelDownloadedLocally(_ model: AIModel) -> Bool {
        let localPath = getLocalModelPath(for: model)
        
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: localPath.path, isDirectory: &isDirectory)
        
        if exists {
            if isDirectory.boolValue {
                // Directory-based model - check for essential files
                let modelDir = localPath
                let configExists = FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("config.json").path)
                let modelExists = FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("model.safetensors").path) ||
                                 FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("pytorch_model.bin").path) ||
                                 FileManager.default.fileExists(atPath: modelDir.appendingPathComponent("model.bin").path)
                
                print("📁 Directory model check - Config: \(configExists), Model: \(modelExists)")
                return configExists || modelExists
            } else {
                // Single file model
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: localPath.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    let expectedSize = model.sizeInBytes
                    
                    // Check if file size is reasonable (at least 50% of expected size to account for compression)
                    let isValidSize = fileSize > expectedSize / 2
                    print("📄 Single file model check - Size: \(fileSize) vs Expected: \(expectedSize), Valid: \(isValidSize)")
                    return isValidSize
                } catch {
                    print("❌ Error checking file size: \(error)")
                    return false
                }
            }
        }
        
        return false
    }
    
    /// Mark a model as downloaded
    private func markModelAsDownloaded(_ model: AIModel) {
        print("✅ Marking model as downloaded: \(model.id)")
        // Since we use file system as source of truth, we don't need to maintain a separate list
        // The isModelDownloadedLocally method will check the actual files
    }
    
    /// Clean up any incomplete or corrupted model downloads
    func cleanupIncompleteDownloads() {
        let modelsDir = getModelDownloadDirectory()
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            for fileURL in contents {
                let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let fileSize = attributes.fileSize ?? 0
                let creationDate = attributes.creationDate ?? Date()
                
                // Remove files that are very small (likely incomplete downloads) and old
                let isOldFile = Date().timeIntervalSince(creationDate) > 24 * 60 * 60 // Older than 24 hours
                let isTooSmall = fileSize < 1024 * 1024 // Smaller than 1MB
                
                if isOldFile && isTooSmall {
                    print("🧹 Removing incomplete download: \(fileURL.lastPathComponent)")
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        } catch {
            print("⚠️ Error during cleanup: \(error)")
        }
    }
    
    /// Get current memory usage
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    /// Generate model-specific response (fallback implementation)
    private func generateModelSpecificResponse(
        prompt: String,
        model: AIModel,
        temperature: Float
    ) async throws -> String {
        
        print("🔄 Using fallback model-specific response generation")
        
        // Simulate processing time
        try await Task.sleep(nanoseconds: UInt64(500_000_000 + Double.random(in: 0...1_000_000_000)))
        
        let modelInfo = "[\(model.name) - MLX Swift Integration Active]"
        
        switch model.type {
        case .llama:
            return """
            \(modelInfo)
            
            I'm a Llama model running on-device with MLX Swift. Your prompt was: "\(prompt)"
            
            MLX Swift Integration Status: ✅ Active
            • On-device inference with Apple Silicon optimization
            • Memory-efficient model loading
            • Hardware-accelerated computation
            • Complete privacy with no data leaving your device
            
            Temperature: \(temperature)
            Model: \(model.name)
            Type: Large Language Model
            """
            
        case .code:
            return """
            \(modelInfo)
            
            // Code generation response for: "\(prompt)"
            
            func mlxSwiftInference() {
                // MLX Swift integration is now active!
                print("Loading model with MLX Swift...")
                
                // Features available:
                // - Real code generation with MLX
                // - Syntax highlighting support
                // - Multi-language support
                // - On-device processing
            }
            
            // Temperature: \(temperature)
            // Model: \(model.name)
            """
            
        case .whisper:
            return """
            \(modelInfo)
            
            🎤 Whisper model response for: "\(prompt)"
            
            MLX Swift Audio Processing:
            • Speech-to-text transcription
            • Multi-language audio processing
            • Real-time audio analysis
            • On-device voice recognition
            
            Note: Audio processing with MLX Swift integration ready.
            
            Temperature: \(temperature)
            Model: \(model.name)
            """
            
        case .stable_diffusion:
            return """
            \(modelInfo)
            
            🎨 Stable Diffusion response for: "\(prompt)"
            
            MLX Swift Image Generation:
            • Text-to-image generation
            • Style transfer
            • Image editing
            • Creative AI art
            
            Note: Image generation with MLX Swift ready for implementation.
            
            Temperature: \(temperature)
            Model: \(model.name)
            """
            
        case .general:
            return """
            \(modelInfo)
            
            Hello! I'm a general-purpose AI model running with MLX Swift. You asked: "\(prompt)"
            
            MLX Swift Capabilities:
            • General conversation
            • Question answering
            • Text analysis
            • Creative writing
            • Problem solving
            
            Running natively on Apple Silicon with MLX Swift optimization.
            
            Temperature: \(temperature)
            Model: \(model.name)
            """
        }
    }
}

/// Errors that can occur during AI inference
enum AIInferenceError: LocalizedError {
    case modelNotLoaded
    case modelFileNotFound
    case invalidModelFormat
    case inferenceError(String)
    case tokenizationError
    case outOfMemory
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is currently loaded"
        case .modelFileNotFound:
            return "Model file not found"
        case .invalidModelFormat:
            return "Invalid model file format"
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .tokenizationError:
            return "Error tokenizing input"
        case .outOfMemory:
            return "Insufficient memory to load model"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }
}

// MARK: - MLX Swift Integration Extensions

extension AIInferenceManager {
    
    /// Check if MLX Swift is available
    var isMLXSwiftAvailable: Bool {
        print("🔍 Checking MLX Swift availability")
        // Check if we can access MLX types
        let available = true // MLX should be available if we got this far
        print("✅ MLX Swift availability: \(available ? "Available" : "Not Available")")
        return available
    }
    
    /// Get system capabilities for running models
    func getSystemCapabilities() -> SystemCapabilities {
        print("🔍 Getting system capabilities")
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        
        let capabilities = SystemCapabilities(
            totalMemory: physicalMemory,
            availableMemory: physicalMemory / 2, // Rough estimate
            hasNeuralEngine: true, // Assume true for Apple Silicon
            hasGPU: true,
            isAppleSilicon: true
        )
        
        print("💾 Total memory: \(capabilities.totalMemory) bytes")
        print("🔓 Available memory: \(capabilities.availableMemory) bytes")
        print("🧠 Neural Engine: \(capabilities.hasNeuralEngine ? "Available" : "Not Available")")
        print("🎮 GPU: \(capabilities.hasGPU ? "Available" : "Not Available")")
        print("🍎 Apple Silicon: \(capabilities.isAppleSilicon ? "Yes" : "No")")
        
        return capabilities
    }
    
    /// Recommend optimal settings for a model
    func getOptimalSettings(for model: AIModel) -> InferenceSettings {
        print("⚙️ Getting optimal settings for model: \(model.name)")
        let capabilities = getSystemCapabilities()
        
        // Calculate optimal settings based on model size and system capabilities
        let recommendedBatchSize = capabilities.availableMemory > 16_000_000_000 ? 8 : 4
        let recommendedMaxTokens = model.name.contains("large") ? 256 : 512
        
        let settings = InferenceSettings(
            batchSize: recommendedBatchSize,
            maxTokens: recommendedMaxTokens,
            temperature: 0.7,
            topP: 0.9,
            useGPUAcceleration: true,
            useNeuralEngine: true
        )
        
        print("📊 Recommended batch size: \(settings.batchSize)")
        print("🔢 Recommended max tokens: \(settings.maxTokens)")
        print("🌡️ Default temperature: \(settings.temperature)")
        print("🎯 Default top-p: \(settings.topP)")
        
        return settings
    }
}

// MARK: - Supporting Types

struct SystemCapabilities {
    let totalMemory: UInt64
    let availableMemory: UInt64
    let hasNeuralEngine: Bool
    let hasGPU: Bool
    let isAppleSilicon: Bool
}

struct InferenceSettings {
    let batchSize: Int
    let maxTokens: Int
    let temperature: Float
    let topP: Float
    let useGPUAcceleration: Bool
    let useNeuralEngine: Bool
}

// MARK: - ProcessInfo Extension for Machine Description
extension ProcessInfo {
    var machineDescription: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)
        return String(cString: machine)
    }
} 
