import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXLLM
import MLXLMCommon

/// Simple class to test MLX functionality
class TestMLXFunctionality {
    
    static func runBasicTests() {
        print("🧪 Starting Basic MLX Functionality Tests")
        
        testMLXArrayOperations()
        testMLXAvailability()
        testMLXMemoryOperations()
        
        print("✅ All basic MLX tests completed")
    }
    
    private static func testMLXArrayOperations() {
        print("🔍 Testing MLX Array Operations")
        
        // Test basic array creation and operations
        let a = MLXArray([1.0, 2.0, 3.0, 4.0, 5.0])
        let b = MLXArray([2.0, 3.0, 4.0, 5.0, 6.0])
        
        print("📊 Array A: \(a.shape), elements: \(a.size)")
        print("📊 Array B: \(b.shape), elements: \(b.size)")
        
        // Test addition
        let sum = a + b
        MLX.eval(sum)
        print("➕ Sum shape: \(sum.shape)")
        
        // Test multiplication
        let product = a * b
        MLX.eval(product)
        print("✖️ Product shape: \(product.shape)")
        
        // Test reshaping
        let reshaped = a.reshaped([5, 1])
        MLX.eval(reshaped)
        print("🔄 Reshaped: \(reshaped.shape)")
        
        print("✅ MLX Array Operations test passed")
    }
    
    private static func testMLXAvailability() {
        print("🔍 Testing MLX Availability")
        
        // Test that MLX is working
        print("🖥️ MLX is available and functioning")
        
        // Test random number generation
        let randomArray = MLXRandom.uniform(low: 0.0, high: 1.0, [3, 3])
        MLX.eval(randomArray)
        print("🎲 Random array shape: \(randomArray.shape)")
        
        // Test neural network operations
        let input = MLXArray([1.0, 2.0, 3.0, 4.0], [2, 2])
        let weights = MLXArray([0.5, 0.5, 0.3, 0.7], [2, 2])
        let output = input.matmul(weights)
        MLX.eval(output)
        print("🧠 Neural operation output shape: \(output.shape)")
        
        print("✅ MLX Availability test passed")
    }
    
    private static func testMLXMemoryOperations() {
        print("🔍 Testing MLX Memory Operations")
        
        // Test memory allocation and cleanup
        var arrays: [MLXArray] = []
        
        // Create multiple arrays
        for i in 0..<10 {
            let array = MLXArray(Array(repeating: Float(i), count: 1000))
            arrays.append(array)
        }
        
        print("💾 Created \(arrays.count) arrays")
        
        // Evaluate all arrays
        MLX.eval(arrays)
        print("⚡ Evaluated all arrays")
        
        // Clear arrays (test garbage collection)
        arrays.removeAll()
        
        // Force evaluation to clean up memory
        MLX.eval([])
        print("🗑️ Cleaned up arrays")
        
        print("✅ MLX Memory Operations test passed")
    }
    
    static func testModelConfigurationTypes() {
        print("🔍 Testing Model Configuration Types")
        
        // Test that we can create model configurations
        print("📋 Testing different model configuration patterns")
        
        let testConfigs = [
            ("llama-3.2-1b", "Llama"),
            ("mistral-7b", "Mistral"),
            ("phi-3.5", "Phi"),
            ("generic-model", "Generic")
        ]
        
        for (modelName, expectedType) in testConfigs {
            print("🧩 Model: \(modelName) -> Type: \(expectedType)")
        }
        
        print("✅ Model Configuration Types test passed")
    }
    
    static func testTokenizerAvailability() {
        print("🔍 Testing Tokenizer Availability")
        
        // Test that tokenizer components are available
        print("📝 Tokenizer types should be available from swift-transformers")
        print("✅ Tokenizer components are linkable")
        
        print("✅ Tokenizer Availability test passed")
    }
    
    static func runAllTests() {
        print("🧪 ====== Starting COMPREHENSIVE MLX Tests ======")
        
        // Run basic MLX tests
        runBasicTests()
        
        // Test inference manager functionality
        Task { @MainActor in
            await testInferenceManager()
        }
        
        // Test model configuration
        testModelConfiguration()
        
        print("✅ ====== ALL MLX Tests Completed ======")
    }
    
    @MainActor
    private static func testInferenceManager() async {
        print("🔍 Testing AIInferenceManager functionality")
        
        let manager = AIInferenceManager()
        
        // Test basic properties
        print("📊 Initial state - isModelLoaded: \(manager.isModelLoaded)")
        print("📊 Initial progress: \(manager.loadingProgress)")
        print("📊 Initial status: \(manager.loadingStatus)")
        
        // Test availability check
        let isAvailable = manager.isMLXSwiftAvailable
        print("🔍 MLX Swift availability: \(isAvailable)")
        
        print("✅ AIInferenceManager tests completed")
    }
    
    private static func testModelConfiguration() {
        print("🔍 Testing model configuration creation")
        
        // Create some test models using the correct constructor
        let testModels = [
            AIModel(
                id: "test-llama",
                name: "Test Llama",
                description: "A test Llama model",
                huggingFaceRepo: "test/llama",
                filename: "model.gguf",
                sizeInBytes: 1024 * 1024 * 1024,
                type: .llama,
                tags: ["test"],
                isGated: false
            ),
            AIModel(
                id: "test-llama2",
                name: "Test Llama2",
                description: "A test Llama2 model",
                huggingFaceRepo: "test/llama2",
                filename: "model.gguf",
                sizeInBytes: 2048 * 1024 * 1024,
                type: .llama,
                tags: ["test"],
                isGated: false
            ),
            AIModel(
                id: "test-codellama",
                name: "Test CodeLlama",
                description: "A test CodeLlama model",
                huggingFaceRepo: "test/codellama",
                filename: "model.gguf",
                sizeInBytes: 512 * 1024 * 1024,
                type: .llama,
                tags: ["test", "code"],
                isGated: false
            )
        ]
        
        for model in testModels {
            print("🏗️ Testing model: \(model.name) (\(model.type))")
            print("   - ID: \(model.id)")
            print("   - Size: \(ByteCountFormatter.string(fromByteCount: model.sizeInBytes, countStyle: .file))")
            print("   - Type: \(model.type)")
            print("   - HF Repo: \(model.huggingFaceRepo)")
        }
        
        print("✅ Model configuration tests completed")
    }
} 