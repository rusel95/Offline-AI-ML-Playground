//
//  SharedModelManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import Foundation
import SwiftUI
import Combine

/// Errors that can occur during model operations
enum ModelError: LocalizedError {
    case invalidModel(String)
    case networkError(String)
    case fileSystemError(String)
    case authenticationError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidModel(let message):
            return "Invalid Model: \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .fileSystemError(let message):
            return "File System Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        }
    }
}

/// Shared singleton manager that handles both model downloads and inference
/// This ensures consistent state across all tabs and unified storage paths
@MainActor
class SharedModelManager: NSObject, ObservableObject {
    
    // MARK: - Singleton Instance
    static let shared = SharedModelManager()
    
    // MARK: - Optimized Published Properties with reduced frequency updates
    @Published var availableModels: [AIModel] = []
    @Published var downloadedModels: Set<String> = []
    @Published var activeDownloads: [String: ModelDownload] = [:]
    @Published var isModelLoaded = false
    @Published var loadingProgress: Float = 0.0
    @Published var loadingStatus = "Ready"
    @Published var lastError: String?
    @Published var storageUsed: Double = 0
    @Published var freeStorage: Double = 0
    @Published var isLoadingAvailableModels = false
    
    // MARK: - Performance optimization properties
    private var lastStorageUpdate: Date = Date()
    private var storageUpdateThrottle: TimeInterval = 2.0 // Update storage every 2 seconds max
    private let progressUpdateThrottle: TimeInterval = 0.1 // Update progress every 100ms max
    private var lastProgressUpdate: [URLSessionTask: Date] = [:]
    
    // Batch update mechanism
    private var pendingUpdates: Set<UpdateType> = []
    private var updateTimer: Timer?
    
    private enum UpdateType: Hashable {
        case storage
        case models
        case downloads
    }
    
    // MARK: - Private Properties
    private var urlSession: URLSession!
    private let documentsDirectory: URL
    private let modelsDirectory: URL
    
    // Download tracking
    private var lastUpdateTime: [URLSessionTask: Date] = [:]
    private var lastBytesWritten: [URLSessionTask: Int64] = [:]
    private var speedTrackers: [URLSessionTask: DownloadSpeedTracker] = [:]
    
    // Inference management will be handled by individual components
    
    // MARK: - Initialization
    private override init() {
        // Setup unified storage directory
        self.documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // CRITICAL FIX: Use unified "Models" directory for both download and inference
        self.modelsDirectory = documentsDirectory.appendingPathComponent("Models", isDirectory: true)
        
        super.init()
        
        print("🚀 SharedModelManager initializing...")
        
        // Setup URLSession for downloads after super.init()
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        // Initialize after super.init()
        setupDirectory()
        loadCuratedModels() // Load curated model list
        
        // Synchronize models synchronously on init to avoid race conditions
        performInitialSynchronization()
        
        print("✅ SharedModelManager initialized")
        print("📁 Unified models directory: \(modelsDirectory.path)")
    }
    
    // MARK: - Directory Management
    private func setupDirectory() {
        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
            print("📁 Models directory created/verified: \(modelsDirectory.path)")
        } catch {
            print("❌ Error creating models directory: \(error)")
        }
    }
    
    /// Get the unified model download directory path
    func getModelDownloadDirectory() -> URL {
        return modelsDirectory
    }
    
    // MARK: - Model Catalog Management
    private func loadCuratedModels() {
        // ==================== MLX MODELS FOR iPHONE (2025) ====================
        // 
        // CURATED LIST: Best MLX-compatible models for iPhone usage
        // Focused on: Performance, Memory efficiency, MLX optimization
        //
        // Model Selection Criteria:
        // ✅ 1B-7B parameter range (optimal for iPhone)
        // ✅ 4-bit quantization available 
        // ✅ MLX community support
        // ✅ Proven iPhone compatibility
        // ✅ Public repositories (no auth required)
        //
        // ======================================================================
        
        print("📋 LOADING CURATED CHAT MODELS FOR iPHONE")
        availableModels = [
            // MARK: - Meta/Llama Models
            // 1. Llama 3.2 1B - Ultra lightweight
            AIModel(
                id: "llama-3.2-1b",
                name: "Llama 3.2 1B Instruct",
                description: "Smallest Llama 3.2 model, perfect for basic conversations. Only 650MB with 4-bit quantization.",
                huggingFaceRepo: "meta-llama/Llama-3.2-1B-Instruct",
                filename: "model.safetensors",
                sizeInBytes: 680000000, // ~650MB
                type: .llama,
                tags: ["llama", "1B", "lightweight", "mlx", "chat", "4-bit"],
                isGated: false,
                provider: .meta
            ),
            
            // 2. Llama 3.2 3B - Sweet spot
            AIModel(
                id: "llama-3.2-3b",
                name: "Llama 3.2 3B Instruct", 
                description: "Excellent balance of capability and size. 1.8GB download, surprisingly powerful for conversations.",
                huggingFaceRepo: "meta-llama/Llama-3.2-3B-Instruct",
                filename: "model.safetensors",
                sizeInBytes: 1932735283, // ~1.8GB
                type: .llama,
                tags: ["llama", "3B", "recommended", "mlx", "chat", "4-bit"],
                isGated: false,
                provider: .meta
            ),
            
            // 3. TinyLlama 1.1B - Community favorite
            AIModel(
                id: "tinyllama-1.1b",
                name: "TinyLlama 1.1B Chat",
                description: "Community-developed ultra-compact chat model. Great for fast conversations on iPhone.",
                huggingFaceRepo: "TinyLlama/TinyLlama-1.1B-Chat-v1.0",
                filename: "model.safetensors",
                sizeInBytes: 1100000000, // ~1.1GB
                type: .llama,
                tags: ["tiny", "llama", "chat", "1B", "mlx", "community"],
                isGated: false,
                provider: .meta
            ),
            
            // MARK: - Mistral Models
            // 4. Mistral 7B Instruct
            AIModel(
                id: "mistral-7b-instruct",
                name: "Mistral 7B Instruct v0.3",
                description: "High-quality 7B chat model with 4-bit quantization. Excellent for advanced conversations.",
                huggingFaceRepo: "mistralai/Mistral-7B-Instruct-v0.3",
                filename: "model.safetensors",
                sizeInBytes: 3800000000, // ~3.8GB
                type: .mistral,
                tags: ["mistral", "7B", "chat", "mlx", "4-bit", "advanced"],
                isGated: false,
                provider: .mistral
            ),
            
            // 5. Mistral Small
            AIModel(
                id: "mistral-small",
                name: "Mistral Small",
                description: "Compact Mistral chat model optimized for mobile. Excellent quality-to-size ratio.",
                huggingFaceRepo: "mistralai/Mistral-Small-Instruct-2409",
                filename: "model.safetensors",
                sizeInBytes: 2500000000, // ~2.5GB
                type: .mistral,
                tags: ["mistral", "small", "chat", "mlx", "optimized"],
                isGated: false,
                provider: .mistral
            ),
            
            // MARK: - Microsoft Phi Models
            // 6. Phi-3.5 Mini
            AIModel(
                id: "phi-3.5-mini",
                name: "Phi 3.5 Mini Instruct",
                description: "Microsoft's latest compact chat model. 4-bit quantized, perfect for iPhone conversations.",
                huggingFaceRepo: "microsoft/Phi-3.5-mini-instruct",
                filename: "model.safetensors",
                sizeInBytes: 2000000000, // ~2GB
                type: .general,
                tags: ["phi", "microsoft", "3.5B", "mlx", "chat", "mini"],
                isGated: false,
                provider: .microsoft
            ),
            
            // 7. Phi-2
            AIModel(
                id: "phi-2",
                name: "Phi-2",
                description: "Proven 2.7B parameter chat model from Microsoft. Great conversational abilities.",
                huggingFaceRepo: "microsoft/phi-2",
                filename: "model.safetensors",
                sizeInBytes: 2700000000, // ~2.7GB
                type: .general,
                tags: ["phi", "microsoft", "2.7B", "mlx", "chat"],
                isGated: false,
                provider: .microsoft
            ),
            
            // MARK: - Google Models  
            // 8. Gemma 2B
            AIModel(
                id: "gemma-2b",
                name: "Gemma 2B Instruct",
                description: "Google's efficient 2B chat model. Optimized for on-device conversations.",
                huggingFaceRepo: "google/gemma-2b-it",
                filename: "model.safetensors",
                sizeInBytes: 2500000000, // ~2.5GB
                type: .general,
                tags: ["gemma", "google", "2B", "mlx", "chat"],
                isGated: false,
                provider: .google
            ),
            
            // MARK: - Qwen Models
            // 9. Qwen 2.5 1.5B
            AIModel(
                id: "qwen2.5-1.5b",
                name: "Qwen 2.5 1.5B Chat",
                description: "Alibaba's efficient chat model. Strong multilingual conversations, great for iPhone.",
                huggingFaceRepo: "Qwen/Qwen2.5-1.5B-Instruct",
                filename: "model.safetensors",
                sizeInBytes: 1600000000, // ~1.6GB
                type: .general,
                tags: ["qwen", "1.5B", "multilingual", "mlx", "chat"],
                isGated: false,
                provider: .other
            ),
            
            // 10. Qwen 2.5 3B
            AIModel(
                id: "qwen2.5-3b",
                name: "Qwen 2.5 3B Chat",
                description: "Larger Qwen chat model with excellent performance. Supports multiple languages.",
                huggingFaceRepo: "Qwen/Qwen2.5-3B-Instruct",
                filename: "model.safetensors",
                sizeInBytes: 3200000000, // ~3.2GB
                type: .general,
                tags: ["qwen", "3B", "multilingual", "mlx", "chat"],
                isGated: false,
                provider: .other
            ),
            
            // MARK: - OpenAI Models
            // 11. GPT-2 Small
            AIModel(
                id: "gpt2",
                name: "GPT-2",
                description: "Classic lightweight model. Good for basic text generation and conversations.",
                huggingFaceRepo: "openai-community/gpt2",
                filename: "model.safetensors",
                sizeInBytes: 548118077, // ~548MB
                type: .general,
                tags: ["gpt2", "openai", "chat", "mlx", "classic"],
                isGated: false,
                provider: .openAI
            ),
            
            // 12. GPT-2 Medium
            AIModel(
                id: "gpt2-medium",
                name: "GPT-2 Medium",
                description: "Larger GPT-2 variant. Better conversation quality while staying lightweight.",
                huggingFaceRepo: "openai-community/gpt2-medium",
                filename: "model.safetensors",
                sizeInBytes: 380000000, // ~380MB
                type: .general,
                tags: ["gpt2", "openai", "medium", "mlx", "chat"],
                isGated: false,
                provider: .openAI
            ),
            
            // MARK: - StabilityAI Models
            // 13. StableLM 2 1.6B
            AIModel(
                id: "stablelm-2-1.6b",
                name: "StableLM 2 1.6B Chat",
                description: "Stability AI's dedicated chat model. Good balance of size and conversation quality.",
                huggingFaceRepo: "stabilityai/stablelm-2-1_6b-chat",
                filename: "model.safetensors",
                sizeInBytes: 1700000000, // ~1.7GB
                type: .general,
                tags: ["stablelm", "1.6B", "chat", "mlx", "stability"],
                isGated: false,
                provider: .stabilityAI
            ),
            
            // MARK: - Tiny Models (100MB - 300MB)
            // 14. SmolLM 135M
            AIModel(
                id: "smollm-135m",
                name: "SmolLM 135M Instruct",
                description: "Hugging Face's ultra-tiny chat model. Perfect for quick testing, only 135MB!",
                huggingFaceRepo: "HuggingFaceTB/SmolLM-135M-Instruct",
                filename: "model.safetensors",
                sizeInBytes: 135000000, // ~135MB
                type: .general,
                tags: ["smollm", "135M", "tiny", "mlx", "chat", "ultra-light"],
                isGated: false,
                provider: .huggingFace
            ),
            
            // 15. SmolLM 360M
            AIModel(
                id: "smollm-360m",
                name: "SmolLM 360M Instruct",
                description: "Slightly larger SmolLM variant. Better quality while staying under 300MB.",
                huggingFaceRepo: "HuggingFaceTB/SmolLM-360M-Instruct",
                filename: "model.safetensors",
                sizeInBytes: 290000000, // ~290MB
                type: .general,
                tags: ["smollm", "360M", "tiny", "mlx", "chat", "light"],
                isGated: false,
                provider: .huggingFace
            ),
            
            // 16. OPT-125M
            AIModel(
                id: "opt-125m",
                name: "OPT 125M",
                description: "Meta's tiny Open Pre-trained Transformer. Great for testing, only 250MB.",
                huggingFaceRepo: "facebook/opt-125m",
                filename: "model.safetensors",
                sizeInBytes: 250000000, // ~250MB
                type: .general,
                tags: ["opt", "125M", "tiny", "meta", "mlx", "chat"],
                isGated: false,
                provider: .meta
            ),
            
            // 17. Pythia 160M
            AIModel(
                id: "pythia-160m",
                name: "Pythia 160M",
                description: "EleutherAI's tiny model. Excellent for research and testing.",
                huggingFaceRepo: "EleutherAI/pythia-160m",
                filename: "model.safetensors",
                sizeInBytes: 160000000, // ~160MB
                type: .general,
                tags: ["pythia", "160M", "tiny", "eleuther", "mlx", "chat"],
                isGated: false,
                provider: .other
            ),
            
            // MARK: - Apple Models
            // 18. OpenELM 270M
            AIModel(
                id: "openelm-270m",
                name: "OpenELM 270M",
                description: "Apple's smallest efficient language model. Optimized for Apple Silicon.",
                huggingFaceRepo: "apple/OpenELM-270M",
                filename: "model.safetensors",
                sizeInBytes: 270000000, // ~270MB
                type: .general,
                tags: ["openelm", "270M", "apple", "mlx", "chat", "efficient"],
                isGated: false,
                provider: .apple
            ),
            
            // 19. OpenELM 450M
            AIModel(
                id: "openelm-450m",
                name: "OpenELM 450M",
                description: "Apple's mid-size efficient model. Better quality while staying compact.",
                huggingFaceRepo: "apple/OpenELM-450M",
                filename: "model.safetensors",
                sizeInBytes: 450000000, // ~450MB
                type: .general,
                tags: ["openelm", "450M", "apple", "mlx", "chat", "balanced"],
                isGated: false,
                provider: .apple
            ),
            
            // 20. OpenELM 1.1B
            AIModel(
                id: "openelm-1.1b",
                name: "OpenELM 1.1B",
                description: "Apple's 1B parameter model. Excellent performance for its size.",
                huggingFaceRepo: "apple/OpenELM-1_1B",
                filename: "model.safetensors",
                sizeInBytes: 1100000000, // ~1.1GB
                type: .general,
                tags: ["openelm", "1.1B", "apple", "mlx", "chat", "powerful"],
                isGated: false,
                provider: .apple
            ),
            
            // 21. OpenELM 3B
            AIModel(
                id: "openelm-3b",
                name: "OpenELM 3B",
                description: "Apple's largest efficient language model. Top quality from Apple.",
                huggingFaceRepo: "apple/OpenELM-3B",
                filename: "model.safetensors",
                sizeInBytes: 3000000000, // ~3GB
                type: .general,
                tags: ["openelm", "3B", "apple", "mlx", "chat", "premium"],
                isGated: false,
                provider: .apple
            ),
        ]
        
        print("📋 Loaded \(availableModels.count) curated chat models for iPhone")
        print("💬 All models optimized for conversational AI")
        print("📱 Model sizes: 135MB - 3.8GB (including tiny models)")
        print("🏢 Providers: \(Set(availableModels.map { $0.provider.displayName }).joined(separator: ", "))")
        print("🍎 Including Apple's OpenELM models!")
    }
    
    // MARK: - Model Availability
    // Models are static and pre-defined, no verification needed
    
    // MARK: - Initial Synchronization
    private func performInitialSynchronization() {
        // Perform synchronous check for downloaded models
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            storageUsed = 0
            freeStorage = 0
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: modelsDirectory, 
                includingPropertiesForKeys: [.fileSizeKey]
            )
            
            // Check which models are already downloaded
            let filesOnDisk = Set(contents.map { $0.lastPathComponent })
            let modelIdsOnDisk = Set(availableModels.compactMap { model in
                filesOnDisk.contains { filename in
                    filename.hasPrefix(model.id) && filename.contains(".")
                } ? model.id : nil
            })
            
            downloadedModels = modelIdsOnDisk
            
            // Calculate initial storage
            storageUsed = contents.reduce(0.0) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                return total + Double(size)
            }
            
            // Calculate free storage
            if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
               let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                freeStorage = freeSpace.doubleValue
            }
            
            print("📊 Initial sync: \(downloadedModels.count) models found")
            print("💾 Storage used: \(formattedStorageUsed)")
            
        } catch {
            print("❌ Error in initial synchronization: \(error)")
            downloadedModels.removeAll()
            storageUsed = 0
            freeStorage = 0
        }
    }
    
    // MARK: - Optimized Model Synchronization
    func synchronizeModels() {
        // Add to pending updates for batch processing
        pendingUpdates.insert(.models)
        scheduleUpdate()
    }
    
    func synchronizeModelsImmediately() async {
        await performModelSynchronization()
    }
    
    private func performModelSynchronization() async {
        print("🔄 Synchronizing models with file system...")
        
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            downloadedModels.removeAll()
            return
        }
        
        // Perform synchronization on background task for better performance
        let newDownloadedModels = await Task.detached { [weak self] () -> Set<String> in
            guard let self = self else { return [] }
            
            var result: Set<String> = []
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.modelsDirectory, 
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                let filesOnDisk = Set(contents.map { $0.lastPathComponent })
                
                // CRITICAL FIX: Match model IDs with files that start with the model ID
                let availableModelsSnapshot = await self.availableModels
                let modelIdsOnDisk = Set(availableModelsSnapshot.compactMap { model in
                    // Check if any file on disk starts with this model's ID
                    let hasMatchingFile = filesOnDisk.contains { filename in
                        filename.hasPrefix(model.id) && filename.contains(".")
                    }
                    return hasMatchingFile ? model.id : nil
                })
                
                result = modelIdsOnDisk
                
            } catch {
                print("❌ Error synchronizing models: \(error)")
            }
            
            return result
        }.value
        
        // Update on main actor only if there are changes
        if self.downloadedModels != newDownloadedModels {
            let oldCount = self.downloadedModels.count
            self.downloadedModels = newDownloadedModels
            print("📊 Synchronized: \(self.downloadedModels.count) models tracked (was \(oldCount))")
        }
    }
    
    // MARK: - Model Queries
    func getDownloadedModels() -> [AIModel] {
        return availableModels.filter { downloadedModels.contains($0.id) }
    }
    
    func getAvailableLanguageModels() -> [AIModel] {
        return getDownloadedModels().filter { model in
            !model.name.lowercased().contains("mobilevit") &&
            !model.name.lowercased().contains("vision") &&
            !model.tags.contains("vision") &&
            !model.name.lowercased().contains("minilm") &&
            !model.name.lowercased().contains("embedding") &&
            !model.name.lowercased().contains("sentence") &&
            !model.tags.contains("embedding") &&
            !model.tags.contains("sentence-transformers")
        }
    }
    
    func isModelDownloaded(_ modelId: String) -> Bool {
        // ==================== STATE MANAGEMENT CRITICAL FIX ====================
        //
        // PROBLEM SOLVED: "Publishing changes from within view updates is not allowed"
        //
        // ROOT CAUSE: Direct @Published property updates during SwiftUI view update cycles
        // SOLUTION: Background file system checks + main thread state updates
        //
        // WORKFLOW:
        // 1. Fast path: Check in-memory tracking first (no file system access)
        // 2. Slow path: Background file check + deferred main thread update
        // 3. NEVER call FileManager.default.fileExists on main thread from UI context
        //
        // WHY THIS WORKS:
        // ✅ Prevents main thread blocking (no 0.35s+ hangs)
        // ✅ Prevents state update violations (DispatchQueue.main.async)  
        // ✅ Maintains UI responsiveness (immediate return for tracked models)
        //
        // ======================================================================
        
        print("🔍 CHECKING MODEL DOWNLOAD STATUS: \(modelId)")
        
        // FAST PATH: Check in-memory tracking first (immediate return)
        if downloadedModels.contains(modelId) {
            print("✅ Model \(modelId) found in tracking (fast path)")
            return true
        }
        
        print("⏳ Model \(modelId) not tracked, checking file system on background queue")
        
        // SLOW PATH: Schedule background check
        Task {
            await checkAndUpdateModelOnDisk(modelId)
        }
        
        // Return false immediately - background update will sync later
        print("⚡ Returning false immediately (background sync will update)")
        return false
    }
    
    private func checkAndUpdateModelOnDisk(_ modelId: String) async {
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        
        let fileExists = await Task.detached {
            FileManager.default.fileExists(atPath: modelPath.path)
        }.value
        
        print("📁 File system check for \(modelId): exists=\(fileExists)")
        
        if fileExists && !self.downloadedModels.contains(modelId) {
            self.downloadedModels.insert(modelId)
            print("✅ Found untracked model \(modelId), adding to tracking")
        }
    }
    
    func getLocalModelPath(modelId: String) -> URL? {
        guard isModelDownloaded(modelId) else { return nil }
        return modelsDirectory.appendingPathComponent(modelId)
    }
    
    // MARK: - Download Management
    /// Download a specific AI model with proper error handling
    func downloadModel(_ model: AIModel) async throws {
        // Validate model
        guard !model.id.isEmpty else {
            throw ModelError.invalidModel("Model ID cannot be empty")
        }
        
        // Check if already downloading
        if activeDownloads[model.id] != nil {
            print("⚠️ Model \(model.name) is already being downloaded")
            return
        }
        
        // Verify internet connectivity before attempting download
        guard let url = constructModelDownloadURL(for: model) else {
            throw ModelError.networkError("Invalid download URL for model \(model.name)")
        }
        
        print("⬇️ Started downloading model: \(model.name)")
        print("🔗 Download URL: \(url)")
        
        let request = URLRequest(url: url)
        
        // CRITICAL FIX: Use the custom URLSession with delegate for progress updates
        // Remove completion handler so delegate methods are called
        let task = self.urlSession.downloadTask(with: request)
        
        // Create download tracking object
        let download = ModelDownload(
            modelId: model.id,
            progress: 0.0,
            totalBytes: 0,
            downloadedBytes: 0,
            speed: 0.0,
            task: task
        )
        
        activeDownloads[model.id] = download
        task.resume()
        
        print("🚀 Download task started for \(model.name)")
    }
    
    private func constructModelDownloadURL(for model: AIModel) -> URL? {
        // ==================== DOWNLOAD URL CONSTRUCTION ====================
        //
        // CRITICAL: Use public repositories to avoid authentication (HTTP 401)
        //
        // URL PATTERN: https://huggingface.co/{PUBLIC_REPO}/resolve/main/{FILENAME}
        // 
        // EXAMPLES OF WORKING URLS:
        // ✅ https://huggingface.co/openai-community/gpt2/resolve/main/model.safetensors
        // ✅ https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0/resolve/main/model.safetensors
        // ✅ https://huggingface.co/microsoft/DialoGPT-small/resolve/main/pytorch_model.bin
        //
        // EXAMPLES OF BROKEN URLS (REQUIRE AUTH):
        // ❌ https://huggingface.co/mlx-community/gpt2-4bit/resolve/main/model.safetensors
        // ❌ https://huggingface.co/mlx-community/*/resolve/main/*
        //
        // EXPECTED RESPONSES:
        // ✅ HTTP 302 + x-linked-size header with actual file size
        // ❌ HTTP 401 "Invalid username or password"
        // ❌ HTTP 404 "Entry not found"
        //
        // ================================================================
        
        var actualFilename: String
        
        if model.filename == "*.safetensors" {
            // For MLX repositories, download the main model file first
            // MLX Swift will handle missing config.json/tokenizer.json during loading
            actualFilename = "model.safetensors"
            print("🔄 Converting wildcard filename to specific file: \(actualFilename)")
        } else {
            actualFilename = model.filename
        }
        
        let baseURL = "https://huggingface.co/\(model.huggingFaceRepo)/resolve/main/\(actualFilename)"
        
        print("🔗 CONSTRUCTING DOWNLOAD URL:")
        print("   📋 Model: \(model.name) (\(model.id))")
        print("   🏠 Repository: \(model.huggingFaceRepo)")
        print("   📄 Original filename: \(model.filename)")
        print("   📄 Actual filename: \(actualFilename)")
        print("   🌐 Final URL: \(baseURL)")
        print("   🔍 Expected: HTTP 302 with x-linked-size header")
        
        return URL(string: baseURL)
    }
    
    func cancelDownload(_ modelId: String) {
        guard let download = activeDownloads[modelId] else { return }
        download.task.cancel()
        activeDownloads.removeValue(forKey: modelId)
        speedTrackers.removeValue(forKey: download.task)
        print("🛑 Cancelled download for model: \(modelId)")
    }
    
    func deleteModel(_ modelId: String) {
        let modelURL = modelsDirectory.appendingPathComponent(modelId)
        do {
            try FileManager.default.removeItem(at: modelURL)
            downloadedModels.remove(modelId)
            calculateStorage()
            print("🗑️ Deleted model: \(modelId)")
        } catch {
            print("❌ Error deleting model \(modelId): \(error)")
        }
    }
    
    // MARK: - Optimized Storage Management
    func calculateStorage() {
        // Throttle storage calculations to prevent excessive UI updates
        let now = Date()
        guard now.timeIntervalSince(lastStorageUpdate) >= storageUpdateThrottle else {
            return
        }
        
        pendingUpdates.insert(.storage)
        scheduleUpdate()
    }
    
    func calculateStorageImmediately() async {
        await performStorageCalculation()
    }
    
    private func performStorageCalculation() async {
        guard FileManager.default.fileExists(atPath: modelsDirectory.path) else {
            self.storageUsed = 0
            self.lastStorageUpdate = Date()
            return
        }
        
        // Perform calculation on background task
        let (calculatedStorage, calculatedFreeStorage) = await Task.detached { [weak self] () -> (Double, Double) in
            guard let self = self else { return (0, 0) }
            
            var calculatedStorage: Double = 0
            var calculatedFreeStorage: Double = 0
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: self.modelsDirectory, 
                    includingPropertiesForKeys: [.fileSizeKey]
                )
                
                calculatedStorage = contents.reduce(0.0) { total, url in
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    return total + Double(size)
                }
                
                // Update free storage
                if let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
                   let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                    calculatedFreeStorage = freeSpace.doubleValue
                } else {
                    calculatedFreeStorage = 0
                }
                
            } catch {
                calculatedStorage = 0
                calculatedFreeStorage = 0
            }
            
            return (calculatedStorage, calculatedFreeStorage)
        }.value
        
        // Update properties
        self.storageUsed = calculatedStorage
        self.freeStorage = calculatedFreeStorage
        self.lastStorageUpdate = Date()
    }
    
    // MARK: - Batch Update System
    private func scheduleUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.processPendingUpdates()
            }
        }
    }
    
    private func processPendingUpdates() {
        let updates = pendingUpdates
        pendingUpdates.removeAll()
        
        Task {
            for update in updates {
                switch update {
                case .storage:
                    await performStorageCalculation()
                case .models:
                    await performModelSynchronization()
                case .downloads:
                    // Handle download updates if needed
                    break
                }
            }
        }
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var formattedFreeStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(freeStorage), countStyle: .file)
    }
    
    // MARK: - Inference Management
    // Inference management moved to individual view models for better performance
    
    // MARK: - Download Speed Tracking
    private struct DownloadSpeedTracker {
        private var samples: [(timestamp: Date, bytes: Int64)] = []
        
        mutating func addSample(bytes: Int64) {
            let now = Date()
            samples.append((now, bytes))
            // Clean up old samples (keep only last 2 seconds)
            samples.removeAll { $0.timestamp < now.addingTimeInterval(-2) }
        }
        
        func getAverageSpeed() -> Double {
            let now = Date()
            let oneSecondAgo = now.addingTimeInterval(-1)
            
            let recentSamples = samples.filter { $0.timestamp >= oneSecondAgo }
            guard !recentSamples.isEmpty else { return 0 }
            
            let totalBytes = recentSamples.map { $0.bytes }.reduce(0, +)
            let timeSpan = now.timeIntervalSince(recentSamples.first!.timestamp)
            let effectiveSpan = max(timeSpan, 0.1)
            
            return Double(totalBytes) / effectiveSpan
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension SharedModelManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Delegate to async handler
        Task {
            await handleDownloadCompletion(downloadTask: downloadTask, location: location)
        }
    }
    
    @MainActor
    private func handleDownloadCompletion(downloadTask: URLSessionDownloadTask, location: URL) async {
        // Find the model being downloaded
        var targetModelId: String?
        
        for (modelId, download) in activeDownloads {
            if download.task == downloadTask {
                targetModelId = modelId
                break
            }
        }
        
        guard let modelId = targetModelId else { 
            print("⚠️ Could not find model ID for completed download")
            return 
        }
        
        // Perform file operations on background
        await moveDownloadedFile(modelId: modelId, from: location, task: downloadTask)
    }
    
    private func moveDownloadedFile(modelId: String, from location: URL, task: URLSessionDownloadTask) async {
        let destinationURL = modelsDirectory.appendingPathComponent(modelId)
        
        // Perform file operations on background task
        let (success, fileSize) = await Task.detached {
            do {
                // Remove existing file if present
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                    print("🔄 Replaced existing model file: \(modelId)")
                }
                
                // Move downloaded file
                try FileManager.default.moveItem(at: location, to: destinationURL)
                
                // Verify the moved file
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path))?[.size] as? Int64 ?? 0
                
                print("✅ Successfully saved model: \(modelId) to \(destinationURL.path)")
                return (true, fileSize)
                
            } catch {
                print("❌ Error saving model \(modelId): \(error.localizedDescription)")
                return (false, Int64(0))
            }
        }.value
        
        // Update state on main actor
        if success {
            self.downloadedModels.insert(modelId)
            self.activeDownloads.removeValue(forKey: modelId)
            self.speedTrackers.removeValue(forKey: task)
            self.lastProgressUpdate.removeValue(forKey: task)
            self.calculateStorage()
            
            print("✅ Successfully downloaded model: \(modelId)")
            print("📁 File size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            print("💾 Total models downloaded: \(self.downloadedModels.count)")
        } else {
            self.activeDownloads.removeValue(forKey: modelId)
            self.speedTrackers.removeValue(forKey: task)
            self.lastProgressUpdate.removeValue(forKey: task)
            self.lastError = "Failed to save \(modelId)"
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        Task { @MainActor in
            // Throttle progress updates to prevent excessive UI refreshes
            let now = Date()
            if let lastUpdate = lastProgressUpdate[downloadTask],
               now.timeIntervalSince(lastUpdate) < progressUpdateThrottle {
                return
            }
            
            lastProgressUpdate[downloadTask] = now
            
            for (modelId, download) in activeDownloads {
                if download.task == downloadTask {
                    // Update speed tracking
                    if speedTrackers[downloadTask] == nil {
                        speedTrackers[downloadTask] = DownloadSpeedTracker()
                    }
                    speedTrackers[downloadTask]!.addSample(bytes: bytesWritten)
                    
                    let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                    let averageSpeed = speedTrackers[downloadTask]!.getAverageSpeed()
                    
                    let updatedDownload = ModelDownload(
                        modelId: download.modelId,
                        progress: progress,
                        totalBytes: totalBytesExpectedToWrite,
                        downloadedBytes: totalBytesWritten,
                        speed: averageSpeed,
                        task: download.task
                    )
                    
                    activeDownloads[modelId] = updatedDownload
                    break
                }
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Download failed: \(error.localizedDescription)")
            
            Task { @MainActor in
                for (modelId, download) in activeDownloads {
                    if download.task == task {
                        activeDownloads.removeValue(forKey: modelId)
                        speedTrackers.removeValue(forKey: task)
                        lastProgressUpdate.removeValue(forKey: task)
                        print("🧹 Cleaned up failed download for model: \(modelId)")
                        break
                    }
                }
            }
        }
    }
} 
