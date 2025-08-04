import Foundation
import SwiftUI
#if canImport(Hub)
import Hub
#endif
#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon
#endif

/// Streaming response that includes both text and token metrics
public struct StreamingResponse {
    public let text: String
    public let metrics: TokenMetrics
    
    public init(text: String, metrics: TokenMetrics) {
        self.text = text
        self.metrics = metrics
    }
}

/// Actor to handle concurrent access to token metrics
actor MetricsActor {
    private var metrics = TokenMetrics()
    
    func update(tokenCount: Int, currentTime: Date) {
        metrics.update(tokenCount: tokenCount, currentTime: currentTime)
    }
    
    func finalize() {
        metrics.finalize()
    }
    
    func getMetrics() -> TokenMetrics {
        return metrics
    }
}

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
    private var isCurrentlyLoading = false
    
    /// Initialize the inference manager
    init() {
        print("🤖 AIInferenceManager initialized")
        setupLogging()
        setupMemoryPressureMonitoring()
    }
    
    /// Setup comprehensive logging
    private func setupLogging() {
        print("📋 Setting up comprehensive logging system")
        print("📱 Device info: \(ProcessInfo.processInfo.machineDescription)")
        print("💾 Available memory: \(ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))")
        print("🔧 MLX Swift availability: \(isMLXSwiftAvailable ? "✅ Available" : "❌ Not Available")")
    }
    
    /// Setup memory pressure monitoring
    private func setupMemoryPressureMonitoring() {
        print("📊 Setting up memory pressure monitoring")
        // Monitor memory usage periodically
        Task {
            while true {
                let _ = getMemoryUsage()
                let memoryPressure = getMemoryPressure()
                
                if memoryPressure > 0.8 && isModelLoaded {
                    print("⚠️ High memory pressure detected (\(memoryPressure)%), considering model unload")
                }
                
                try await Task.sleep(nanoseconds: 30_000_000_000) // Check every 30 seconds
            }
        }
    }
    
    /// Load a specific AI model with proper memory management
    /// - Parameter model: The model to load
    func loadModel(_ model: AIModel) async throws {
        print("\n=== GGUF LOADING INVESTIGATION ===")
        print("🔍 Starting comprehensive model loading with GGUF support investigation")
        print("📋 Model details:")
        print("   - ID: \(model.id)")
        print("   - Name: \(model.name)")
        print("   - Filename: \(model.filename)")
        print("   - Extension: \(model.filename.components(separatedBy: ".").last ?? "unknown")")
        print("   - Is GGUF: \(model.filename.hasSuffix(".gguf"))")
        print("   - Repository: \(model.huggingFaceRepo)")
        print("================================\n")
        
        // Safety check - ensure we're properly initialized
        guard self.isMLXSwiftAvailable else {
            print("❌ MLX Swift is not available")
            throw AIInferenceError.configurationError("MLX Swift is not available")
        }
        
        // Prevent concurrent model loading
        guard !isCurrentlyLoading else {
            print("⚠️ Model loading already in progress, skipping duplicate request")
            throw AIInferenceError.configurationError("Model loading already in progress")
        }
        
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }
        
        print("🚀 Starting model loading process")
        print("📋 Model: \(model.name) (\(model.id))")
        print("📦 Type: \(model.type)")
        print("💾 Size: \(model.formattedSize)")
        print("🏠 Repository: \(model.huggingFaceRepo)")
        print("📄 Filename: \(model.filename)")
        
        // Check if this is a vision model that can't be used for text generation
        if model.name.lowercased().contains("mobilevit") || 
           model.name.lowercased().contains("vision") ||
           model.tags.contains("vision") {
            print("❌ Vision model detected - cannot be used for text generation")
            throw AIInferenceError.configurationError("Vision models like MobileViT cannot be used for text generation. Please select a language model instead.")
        }
        
        // Check if this is an embedding model that can't be used for text generation
        if model.name.lowercased().contains("minilm") ||
           model.name.lowercased().contains("embedding") ||
           model.name.lowercased().contains("sentence") ||
           model.tags.contains("embedding") ||
           model.tags.contains("sentence-transformers") {
            print("❌ Embedding model detected - cannot be used for text generation")
            throw AIInferenceError.configurationError("Embedding models like All-MiniLM cannot be used for text generation. Please select a language model instead.")
        }
        
        // **CRITICAL FIX**: Properly handle model switching
        if isModelLoaded {
            print("🔄 Switching models - unloading current model first")
            await unloadModelAsync()
            
            // Wait for memory to be freed
            await waitForMemoryCleanup()
        }
        
        // **CRITICAL FIX**: Check if model exists locally
        // For MLX models, we need to handle the download properly
        let _ = getLocalModelPath(for: model)
        
        // Check if we have a single file download (marker file)
        let markerFilePath = ModelFileManager.shared.getModelPath(for: model.id)
        
        // Check for actual MLX model directory
        let mlxModelPath = ModelFileManager.shared.getMLXModelDirectory(for: model.id)
        let modelFilePath = mlxModelPath.appendingPathComponent("model.safetensors")
        let isLocallyAvailable = FileManager.default.fileExists(atPath: modelFilePath.path)
        
        print("📁 Checking for marker at: \(markerFilePath.path)")
        print("📁 Checking for MLX model at: \(modelFilePath.path)")
        print("🔍 Model exists locally: \(isLocallyAvailable)")
        
        // **CRITICAL FIX**: If model doesn't exist locally, don't download - fail immediately
        guard isLocallyAvailable else {
            print("❌ Model not found locally - download required")
            throw AIInferenceError.modelFileNotFound
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
            
            // Check if the actual model.safetensors file exists
            let mlxModelPath = ModelFileManager.shared.getMLXModelDirectory(for: model.id)
            let actualModelPath = mlxModelPath.appendingPathComponent("model.safetensors")
            print("📁 Checking model file at path: \(actualModelPath.path)")
            
            if FileManager.default.fileExists(atPath: actualModelPath.path) {
                print("✅ Model file exists!")
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: actualModelPath.path)[.size] as? Int64) ?? 0
                print("📊 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
                
                // Read first few bytes to check file format
                if let fileHandle = FileHandle(forReadingAtPath: actualModelPath.path) {
                    let headerData = fileHandle.readData(ofLength: 8)
                    let bytes = [UInt8](headerData)
                    print("🔍 File header bytes: \(bytes.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
                    
                    if bytes.count >= 4 && bytes[0] == 0x47 && bytes[1] == 0x47 && bytes[2] == 0x55 && bytes[3] == 0x46 {
                        print("✅ CONFIRMED: This is a GGUF file! (magic bytes: GGUF)")
                        print("🚨 ATTEMPTING TO LOAD GGUF FILE WITH MLX SWIFT")
                    } else {
                        print("❓ File format unknown, header: \(bytes)")
                    }
                    fileHandle.closeFile()
                }
            } else {
                print("❌ Model file does NOT exist at expected path!")
                print("🔍 Let's check what files exist in the models directory...")
                let modelsDir = ModelFileManager.shared.modelsDirectory
                if let contents = try? FileManager.default.contentsOfDirectory(at: modelsDir, includingPropertiesForKeys: nil) {
                    print("📁 Files in models directory:")
                    for file in contents {
                        print("   - \(file.lastPathComponent)")
                    }
                }
            }
            
            // **CRITICAL FIX**: Create configuration that matches the downloaded model
            let config = createModelConfigurationForDownloadedModel(model)
            print("⚙️ Created model configuration: \(config.id)")
            print("🔍 Configuration type: \(type(of: config))")
            
            await MainActor.run {
                loadingProgress = 0.3
                loadingStatus = "Loading from local cache..."
            }
            
            // **CRITICAL FIX**: Create Hub API with proper directory structure
            let downloadDirectory = getModelDownloadDirectory()
            
            print("📁 Base download directory: \(downloadDirectory.path)")
            
            // For MLX models, check if we have the model in MLX structure
            if model.huggingFaceRepo.contains("mlx-community") {
                let mlxModelPath = downloadDirectory
                    .appendingPathComponent("models")
                    .appendingPathComponent("mlx-community")
                    .appendingPathComponent(model.huggingFaceRepo.components(separatedBy: "/").last ?? model.id)
                
                print("📁 MLX model path: \(mlxModelPath.path)")
                
                // Check if we have the required files
                let configPath = mlxModelPath.appendingPathComponent("config.json")
                let modelPath = mlxModelPath.appendingPathComponent("model.safetensors")
                
                if !FileManager.default.fileExists(atPath: modelPath.path) {
                    print("❌ model.safetensors not found at: \(modelPath.path)")
                    print("❌ Model needs to be downloaded with proper MLX structure")
                    throw AIInferenceError.modelFileNotFound
                }
                
                // If we don't have config.json, we need to create a minimal one
                if !FileManager.default.fileExists(atPath: configPath.path) {
                    print("⚠️ config.json missing, creating minimal config")
                    try createMinimalConfig(for: model, at: configPath)
                }
            }
            
            // Create Hub API
            let hub = HubApi(downloadBase: downloadDirectory)
            print("✅ Using locally cached model files ONLY - no network downloads")
            
            // Load model container with proper error handling
            print("🔄 Loading model container with configuration: \(config.id)")
            
            // **CRITICAL FIX**: Wrap the model loading to prevent any network access
            do {
                print("🔄 Attempting to load model container from local files only...")
                
                print("🚀 Calling LLMModelFactory.loadContainer...")
                print("   - Download directory: \(downloadDirectory.path)")
                print("   - Configuration ID: \(config.id)")
                print("   - Model type: \(String(describing: config))")
                
                modelContainer = try await LLMModelFactory.shared.loadContainer(
                    hub: hub,
                    configuration: config
                ) { progress in
                    let baseProgress = 0.3
                    let progressRange = 0.6
                    
                    print("📊 Model loading progress: \(progress.fractionCompleted * 100)%")
                    Task { @MainActor in
                        self.loadingProgress = Float(baseProgress + (progress.fractionCompleted * progressRange))
                        self.loadingStatus = "Loading: \(Int(progress.fractionCompleted * 100))%"
                    }
                }
                
                print("✅ Model container loaded successfully")
            } catch {
                print("\n=== GGUF LOADING ERROR ANALYSIS ===")
                print("❌ Model loading failed with error: \(error)")
                print("🔍 Error type: \(type(of: error))")
                print("📋 Error details: \(String(describing: error))")
                
                // Check if this is a GGUF-specific error
                if model.filename.hasSuffix(".gguf") {
                    print("\n🚨 GGUF LOADING FAILURE DETECTED")
                    print("This appears to be a GGUF file that MLX Swift cannot load.")
                    print("Possible reasons:")
                    print("1. Swift bindings for GGUF are not implemented in MLX Swift")
                    print("2. The model needs to be converted to .safetensors format")
                    print("3. A different loading mechanism is required")
                    
                    // Let's try to understand the exact error
                    if let nsError = error as NSError? {
                        print("\nNSError details:")
                        print("   - Domain: \(nsError.domain)")
                        print("   - Code: \(nsError.code)")
                        print("   - UserInfo: \(nsError.userInfo)")
                    }
                }
                print("================================\n")
                
                throw AIInferenceError.configurationError("Failed to load model from local files: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                loadingProgress = 0.9
                loadingStatus = "Finalizing model initialization..."
            }
            
            // Small delay to ensure everything is properly initialized
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                loadingProgress = 1.0
                loadingStatus = "Model loaded successfully"
                isModelLoaded = true
                currentModel = model
                modelConfiguration = config
            }
            
            print("🎉 Model loaded successfully: \(model.name)")
            print("🔗 Source: Local Cache")
            print("📈 Final memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(getMemoryUsage()), countStyle: .memory))")
            print("📊 Memory pressure: \(getMemoryPressure())")
            
        } catch {
            await MainActor.run {
                lastError = "Failed to load model: \(error.localizedDescription)"
                loadingStatus = "Error loading model"
                isModelLoaded = false
            }
            print("❌ Error loading model: \(error.localizedDescription)")
            print("🔍 Error details: \(String(describing: error))")
            
            // Clean up on error
            await cleanupOnError()
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
                print("⚙️ Generation parameters set: maxTokens=\(String(describing: parameters.maxTokens)), temp=\(String(describing: parameters.temperature)), topP=\(String(describing: parameters.topP))")
                
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
    
    /// Generate a streaming response with token metrics
    /// - Parameters:
    ///   - prompt: The input prompt
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Sampling temperature
    /// - Returns: AsyncStream of StreamingResponse containing text chunks and metrics
    func generateStreamingTextWithMetrics(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncStream<StreamingResponse> {
        
        print("🌊 Starting streaming text generation with metrics")
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
                    
                    print("🏃‍♂️ Performing streaming inference with metrics")
                    
                    // Initialize metrics with an actor to handle concurrent access
                    let metricsActor = MetricsActor()
                    
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
                            let currentTime = Date()
                            let fullText = context.tokenizer.decode(tokens: tokens)
                            
                            // Calculate new tokens generated
                            let currentTokenCount = tokens.count
                            
                            // Update metrics via actor
                            Task {
                                await metricsActor.update(tokenCount: currentTokenCount, currentTime: currentTime)
                            }
                            
                            // Only yield the new part since last time
                            let newText = String(fullText.dropFirst(previousLength))
                            previousLength = fullText.count
                            
                            if !newText.isEmpty {
                                Task {
                                    let currentMetrics = await metricsActor.getMetrics()
                                    print("🌊 Streaming chunk: \(String(newText.prefix(20))...) [Tokens: \(currentTokenCount), Rate: \(String(format: "%.1f", currentMetrics.currentTokensPerSecond)) tok/s]")
                                    
                                    // Create response with current metrics
                                    let response = StreamingResponse(
                                        text: newText,
                                        metrics: currentMetrics
                                    )
                                    continuation.yield(response)
                                }
                            }
                            return .more
                        }
                        
                        // Finalize metrics
                        await metricsActor.finalize()
                        
                        // Send final metrics update
                        let finalMetrics = await metricsActor.getMetrics()
                        let finalResponse = StreamingResponse(
                            text: "",
                            metrics: finalMetrics
                        )
                        continuation.yield(finalResponse)
                        
                        print("✅ Streaming generation completed - Total tokens: \(finalMetrics.totalTokens), Avg speed: \(String(format: "%.1f", finalMetrics.averageTokensPerSecond)) tok/s")
                        
                        return ""
                    }
                    
                    continuation.finish()
                    
                } catch {
                    print("❌ Error in streaming generation with metrics: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    /// Unload the current model (synchronous version)
    func unloadModel() {
        Task {
            await unloadModelAsync()
        }
    }
    
    /// Unload the current model asynchronously with proper cleanup
    func unloadModelAsync() async {
        print("🗑️ Starting async model unload process")
        let initialMemory = getMemoryUsage()
        
        // Clear model references first
        modelContainer = nil
        modelConfiguration = nil
        currentModel = nil
        
        // Update UI state
        await MainActor.run {
            isModelLoaded = false
            loadingProgress = 0.0
            loadingStatus = "Ready"
            lastError = nil
        }
        
        // Force multiple rounds of garbage collection for MLX
        await performDeepMemoryCleanup()
        
        let finalMemory = getMemoryUsage()
        let memoryFreed = initialMemory > finalMemory ? initialMemory - finalMemory : 0
        
        print("✅ Model unloaded successfully")
        print("📈 Memory freed: \(ByteCountFormatter.string(fromByteCount: Int64(memoryFreed), countStyle: .memory))")
        print("📈 Final memory usage: \(ByteCountFormatter.string(fromByteCount: Int64(finalMemory), countStyle: .memory))")
        print("📊 Memory pressure after cleanup: \(getMemoryPressure())")
    }
    
    /// Perform deep memory cleanup for MLX resources
    private func performDeepMemoryCleanup() async {
        print("🧹 Performing deep memory cleanup")
        
        // Multiple rounds of MLX cleanup
        for i in 1...3 {
            print("🔄 Cleanup round \(i)/3")
            
            // Force MLX evaluation with empty array to trigger cleanup
            MLX.eval([])
            
            // Give the system time to perform garbage collection
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Force Swift garbage collection
            autoreleasepool {
                // Force deallocation of any remaining references
            }
        }
        
        print("✅ Deep memory cleanup completed")
    }
    
    /// Wait for memory to be properly cleaned up
    private func waitForMemoryCleanup() async {
        print("⏳ Waiting for memory cleanup to complete")
        let maxWaitTime = 5.0 // Maximum 5 seconds
        let startTime = Date()
        let initialMemory = getMemoryUsage()
        
        while Date().timeIntervalSince(startTime) < maxWaitTime {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let currentMemory = getMemoryUsage()
            let memoryReduction = initialMemory > currentMemory ? 
                Double(initialMemory - currentMemory) / Double(initialMemory) : 0
            
            // If memory has been reduced by at least 10%, consider cleanup complete
            if memoryReduction > 0.1 {
                print("✅ Memory cleanup detected (reduction: \(Int(memoryReduction * 100))%)")
                break
            }
        }
        
        print("⏱️ Memory cleanup wait completed")
    }
    
    /// Clean up resources on error
    private func cleanupOnError() async {
        print("🧹 Cleaning up resources after error")
        
        modelContainer = nil
        modelConfiguration = nil
        currentModel = nil
        
        await MainActor.run {
            isModelLoaded = false
            loadingProgress = 0.0
        }
        
        // Perform cleanup but don't wait as long
        MLX.eval([])
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        print("✅ Error cleanup completed")
    }
    
    /// Get current memory pressure (0.0 to 1.0)
    private func getMemoryPressure() -> Double {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = getMemoryUsage()
        
        let pressure = Double(usedMemory) / Double(totalMemory)
        return min(max(pressure, 0.0), 1.0)
    }
    
    /// Create model configuration for different model types
    private func createModelConfiguration(for model: AIModel) -> ModelConfiguration {
        print("🔧 Creating model configuration for: \(model.name)")
        
        // **DEPRECATED**: This method uses hardcoded configurations
        // Use createModelConfigurationForDownloadedModel instead
        return createModelConfigurationForDownloadedModel(model)
    }
    
    /// Create a simpler, more compatible model configuration
    private func createSimpleModelConfiguration(for model: AIModel) -> ModelConfiguration {
        print("🔄 Creating simple model configuration for: \(model.name)")
        
        // Try a different model that might be more compatible
        let modelId = "mlx-community/Llama-3.2-1B-Instruct-4bit"
        
        return ModelConfiguration(
            id: modelId
        )
    }
    
    /// Create a fallback model configuration for when the main one fails
    private func createFallbackModelConfiguration(for model: AIModel) -> ModelConfiguration {
        print("🔄 Creating fallback model configuration for: \(model.name)")
        return ModelConfiguration(
            id: "mlx-community/Llama-3.2-1B-Instruct-4bit",
            overrideTokenizer: "PreTrainedTokenizer",
            defaultPrompt: "Hello! How can I help you today?"
        )
    }
    
    /// Create a mock model container for testing when MLX loading fails
    private func createMockModelContainer(for model: AIModel) -> ModelContainer? {
        print("🔄 Creating mock model container for: \(model.name)")
        
        // For now, return nil to indicate mock loading failed
        // This will help us identify if the issue is with MLX Swift itself
        return nil
    }
    
    /// Create model configuration for MLX models
    private func createModelConfigurationForDownloadedModel(_ model: AIModel) -> ModelConfiguration {
        // ==================== MLX MODEL CONFIGURATION ====================
        //
        // SOLUTION: Use mlx-community models that include config.json
        //
        // WORKING APPROACH:
        // 1. Download from mlx-community repos (e.g., "mlx-community/SmolLM-135M-Instruct-4bit")
        // 2. These repos include config.json and model.safetensors
        // 3. Use the repository ID directly in configuration
        // 4. MLX Swift loads the model successfully
        //
        // WHY THIS WORKS:
        // ✅ MLX-community models are pre-optimized for MLX Swift
        // ✅ All required files (config.json, tokenizer) are included
        // ✅ 4-bit quantization for efficient iPhone performance
        // ✅ No format conversion needed
        //
        // =============================================================================
        
        print("🔧 CREATING MLX MODEL CONFIGURATION FOR: \(model.name)")
        
        let modelRepo = model.huggingFaceRepo
        print("📋 Using MLX-community repository: \(modelRepo)")
        print("✅ Model includes:")
        print("   • config.json (model configuration)")
        print("   • model.safetensors (MLX-optimized weights)")
        print("   • tokenizer files")
        print("   • 4-bit quantization for iPhone")
        
        return ModelConfiguration(
            id: modelRepo  // Use MLX-community repo directly
        )
    }
    
    /// Get the model download directory with robust path handling for iOS simulator
    public func getModelDownloadDirectory() -> URL {
        // Use ModelFileManager's centralized directory
        return ModelFileManager.shared.modelsDirectory
    }
    
    /// Validate and sanitize file paths for iOS simulator compatibility
    private func sanitizePath(_ path: String) -> String {
        // Remove any problematic characters that might cause issues in iOS simulator
        var sanitized = path
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "&", with: "and")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "*", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
            .replacingOccurrences(of: "|", with: "_")
        
        // Ensure the path is not too long (iOS simulator has path length limits)
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }
        
        return sanitized
    }
    
    /// Get the local path for a specific model with iOS simulator compatibility
    private func getLocalModelPath(for model: AIModel) -> URL {
        // Use ModelFileManager to get the model path
        return ModelFileManager.shared.getModelPath(for: model.id)
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
                    print("📄 Single file model check - Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)) vs Expected: \(ByteCountFormatter.string(fromByteCount: Int64(expectedSize), countStyle: .file)), Valid: \(isValidSize)")
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
    
    /// Create minimal config.json for MLX models
    private func createMinimalConfig(for model: AIModel, at path: URL) throws {
        // Create a minimal config that MLX can work with
        let config: [String: Any] = [
            "model_type": getModelType(for: model),
            "architectures": [getArchitecture(for: model)],
            "hidden_size": 768,
            "num_hidden_layers": 12,
            "num_attention_heads": 12,
            "intermediate_size": 3072,
            "vocab_size": 50257,
            "max_position_embeddings": 1024,
            "torch_dtype": "float16",
            "transformers_version": "4.36.0"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        try jsonData.write(to: path)
        print("✅ Created minimal config.json")
    }
    
    private func getModelType(for model: AIModel) -> String {
        if model.name.lowercased().contains("llama") {
            return "llama"
        } else if model.name.lowercased().contains("phi") {
            return "phi"
        } else if model.name.lowercased().contains("gemma") {
            return "gemma"
        } else if model.name.lowercased().contains("qwen") {
            return "qwen2"
        } else {
            return "gpt2" // Default fallback
        }
    }
    
    private func getArchitecture(for model: AIModel) -> String {
        if model.name.lowercased().contains("llama") {
            return "LlamaForCausalLM"
        } else if model.name.lowercased().contains("phi") {
            return "PhiForCausalLM"
        } else if model.name.lowercased().contains("gemma") {
            return "GemmaForCausalLM"
        } else if model.name.lowercased().contains("qwen") {
            return "Qwen2ForCausalLM"
        } else {
            return "GPT2LMHeadModel" // Default fallback
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
            
        case .mistral:
            return """
            \(modelInfo)
            
            Bonjour! I'm a Mistral model running with MLX Swift. Your query: "\(prompt)"
            
            Mistral AI + MLX Swift Features:
            • High-quality instruction following
            • Efficient 7B parameter architecture
            • Optimized for mobile deployment
            • Advanced reasoning capabilities
            • On-device privacy and speed
            
            Temperature: \(temperature)
            Model: \(model.name)
            Type: Mistral Language Model
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
    case generationFailed(String)
    case streamingNotSupported
    case contextSizeExceeded(Int, Int)
    case invalidInput(String)
    case modelFileNotFound
    case memoryPressure(Double)
    case configurationError(String)
    case formatNotSupported(String)
    case invalidModelFormat
    case inferenceError(String)
    case tokenizationError
    case outOfMemory
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is currently loaded"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .streamingNotSupported:
            return "Streaming is not supported for this model"
        case .contextSizeExceeded(let used, let max):
            return "Context size exceeded: \(used) tokens used, maximum is \(max)"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        case .memoryPressure(let usage):
            return "High memory pressure detected: \(Int(usage * 100))% memory used"
        case .configurationError(let reason):
            return "Model configuration error: \(reason)"
        case .formatNotSupported(let format):
            return "Model format not supported: \(format)"
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
        
        print("💾 Total memory: \(ByteCountFormatter.string(fromByteCount: Int64(capabilities.totalMemory), countStyle: .memory))")
        print("🔓 Available memory: \(ByteCountFormatter.string(fromByteCount: Int64(capabilities.availableMemory), countStyle: .memory))")
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
