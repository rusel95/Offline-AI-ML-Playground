//
//  ChatViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import SwiftData

@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var selectedModel: AIModel? {
        didSet {
            // Save the selected model ID to UserDefaults whenever it changes
            UserDefaults.standard.lastSelectedModelID = selectedModel?.id
            print("💾 Saved selected model: \(selectedModel?.name ?? "None")")
        }
    }
    @Published var generationError: String?
    @Published var showingModelPicker = false
    @Published var showingChatHistory = false
    @Published var isGenerating = false
    @Published var currentConversation: Conversation?
    @Published var conversationTitle: String = "New Conversation"
    @Published var isModelLoading = false
    @Published var shouldNavigateToDownloads = false
    @Published var useMaxContext: Bool = true {
        didSet {
            UserDefaults.standard.set(useMaxContext, forKey: "chatUseMaxContext")
        }
    }
    @Published var customContextSize: Int = 10 {
        didSet {
            UserDefaults.standard.set(customContextSize, forKey: "chatCustomContextSize")
        }
    }
    
    // MARK: - Dependencies
    private let sharedManager = SharedModelManager.shared
    private let aiInferenceManager = AIInferenceManager()
    private var historyManager: ChatHistoryManager?
    
    // MARK: - Computed Properties
    var modelDisplayName: String {
        selectedModel?.name ?? "No model loaded"
    }
    
    var availableModels: [AIModel] {
        // Use the filtered language models from shared manager
        return sharedManager.getAvailableLanguageModels()
    }
    
    var hasSavedModelPreference: Bool {
        return UserDefaults.standard.lastSelectedModelID != nil
    }
    
    var savedModelID: String? {
        return UserDefaults.standard.lastSelectedModelID
    }
    
    // MARK: - Initialization
    init() {
        // Restore context preferences
        useMaxContext = UserDefaults.standard.object(forKey: "chatUseMaxContext") as? Bool ?? true
        let savedCustomSize = UserDefaults.standard.integer(forKey: "chatCustomContextSize")
        if savedCustomSize > 0 {
            customContextSize = savedCustomSize
        }
        
        // Load models on first access instead of during init
        Task {
            await loadInitialModel()
        }
    }
    
    // MARK: - Setup Methods
    func setupHistoryManager(_ modelContext: ModelContext) {
        historyManager = ChatHistoryManager(modelContext: modelContext)
    }
    
    private func loadInitialModel() async {
        // Quick check for available models without file system scan
        let availableModels = sharedManager.availableModels
        
        // Try to restore last selected model
        if let savedModelID = UserDefaults.standard.lastSelectedModelID,
           let savedModel = availableModels.first(where: { $0.id == savedModelID }),
           sharedManager.isModelDownloaded(savedModelID) {
            await MainActor.run {
                self.selectedModel = savedModel
            }
        } else {
            // Find first downloaded model
            for model in availableModels {
                if sharedManager.isModelDownloaded(model.id) {
                    await MainActor.run {
                        self.selectedModel = model
                    }
                    break
                }
            }
        }
    }
    
    
    // MARK: - Model Management
    
    private func isVisionOrEmbeddingModel(_ model: AIModel) -> Bool {
        let name = model.name.lowercased()
        return name.contains("mobilevit") ||
               name.contains("vision") ||
               model.tags.contains("vision") ||
               name.contains("minilm") ||
               name.contains("embedding") ||
               name.contains("sentence") ||
               model.tags.contains("embedding") ||
               model.tags.contains("sentence-transformers")
    }
    
    func loadModelForInference(_ model: AIModel) async {
        // Prevent concurrent model loading
        guard !isGenerating && !isModelLoading else {
            print("⚠️ Cannot load model: already generating or loading")
            return
        }
        
        // Ensure model is actually downloaded locally before attempting to load
        let downloadedModels = sharedManager.getDownloadedModels()
        guard downloadedModels.contains(where: { $0.id == model.id }) else {
            await MainActor.run {
                generationError = "Model '\(model.name)' is not downloaded. Please download it from the Download tab first."
            }
            print("❌ Model not locally available for Chat tab: \(model.name)")
            return
        }
        
        await MainActor.run {
            isModelLoading = true
            generationError = nil
        }
        
        print("🔄 Loading model for inference: \(model.name)")
        
        do {
            // Use AIInferenceManager for actual loading with progress
            try await aiInferenceManager.loadModel(model)
            
            await MainActor.run {
                isModelLoading = false
                generationError = nil
            }
            
            print("✅ Model loaded successfully: \(model.name)")
            
        } catch {
            await MainActor.run {
                isModelLoading = false
                generationError = "Failed to load model: \(error.localizedDescription)"
            }
            print("❌ Error loading model: \(error)")
        }
    }
    
    func selectModel(_ model: AIModel) async {
        // Prevent model switching during generation
        guard !isGenerating else {
            print("⚠️ Cannot switch models while generating text")
            return
        }
        
        // Check if it's the same model
        if selectedModel?.id == model.id {
            print("ℹ️ Model \(model.name) is already selected")
            return
        }
        
        print("🔄 Switching to model: \(model.name)")
        
        await MainActor.run {
            selectedModel = model
        }
        
        // Load the new model
        await loadModelForInference(model)
    }
    
    func refreshDownloadedModels() {
        ModelFileManager.shared.refreshDownloadedModels()
        
        // Use a short delay to allow synchronization to complete before checking models
        Task {
            // Small delay to allow file system synchronization to complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                let downloadedModels = sharedManager.getDownloadedModels()
                let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
                let availableModels = self.availableModels // Use filtered list
                
                // Check if currently selected model is still available
                if let selectedModel = selectedModel,
                   !downloadedModels.contains(where: { $0.id == selectedModel.id }) {
                    // Current model no longer available, try to restore from UserDefaults
                    if let savedModelID = lastSelectedModelID,
                       let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
                        // Check if saved model is a vision or embedding model
                        if isVisionOrEmbeddingModel(savedModel) {
                            print("⚠️ Saved model is a vision or embedding model, using fallback")
                            // Use first available language model
                            if let firstModel = availableModels.first {
                                self.selectedModel = firstModel
                                print("🔄 Using first available language model: \(firstModel.name)")
                                Task {
                                    await loadModelForInference(firstModel)
                                }
                            }
                        } else {
                            self.selectedModel = savedModel
                            print("🔄 Current model unavailable, restored saved model: \(savedModel.name)")
                            Task {
                                await loadModelForInference(savedModel)
                            }
                        }
                    }
                    // Fallback to first available model
                    else if let firstModel = availableModels.first {
                        self.selectedModel = firstModel
                        print("🔄 No saved model available, using first language model")
                        
                        if let newModel = self.selectedModel {
                            Task {
                                await loadModelForInference(newModel)
                            }
                        }
                    }
                }
                
                // Model loading is now handled in init() via loadInitialModel()
            }
        }
    }
    
    func clearSavedModelPreference() {
        UserDefaults.standard.lastSelectedModelID = nil
        print("🗑️ Cleared saved model preference")
    }
    
    // MARK: - Chat History Methods
    func startNewConversation() {
        // Save current conversation if it has messages
        if !messages.isEmpty {
            saveCurrentConversation()
        }
        
        // Reset for new conversation
        messages.removeAll()
        currentConversation = nil
        conversationTitle = "New Conversation"
        generationError = nil
    }
    
    func saveCurrentConversation() {
        guard let historyManager = historyManager, !messages.isEmpty else { return }
        
        if let existing = currentConversation {
            // Update existing conversation
            currentConversation = historyManager.saveConversation(
                messages,
                title: conversationTitle,
                existingConversation: existing
            )
        } else {
            // Create new conversation
            currentConversation = historyManager.saveConversation(
                messages,
                title: nil // Let it auto-generate from first message
            )
            conversationTitle = currentConversation?.title ?? "New Conversation"
        }
        
        print("💾 Conversation saved: \(conversationTitle)")
    }
    
    func loadConversation(_ conversation: Conversation) {
        guard let historyManager = historyManager else { return }
        
        // Save current conversation if it has unsaved changes
        if !messages.isEmpty && currentConversation?.id != conversation.id {
            saveCurrentConversation()
        }
        
        // Load the selected conversation
        messages = historyManager.loadConversation(conversation)
        currentConversation = conversation
        conversationTitle = conversation.title
        
        // Set the model used in this conversation if available and different from current
        if let modelName = conversation.modelUsed,
           let model = availableModels.first(where: { $0.name == modelName }),
           selectedModel?.name != modelName {
            selectedModel = model
            print("🔄 Switched to conversation's model: \(modelName)")
            Task {
                await loadModelForInference(model)
            }
        }
        
        print("📂 Conversation loaded: \(conversationTitle)")
    }
    
    func clearConversation() {
        startNewConversation()
    }
    
    // MARK: - Chat Functions
    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let model = selectedModel else {
            generationError = "No model selected. Please select a model first."
            return
        }
        
        // Add user message
        let userMessage = ChatMessage(
            content: content,
            role: .user,
            timestamp: Date(),
            modelUsed: nil
        )
        messages.append(userMessage)
        
        // Auto-save after each message exchange
        defer {
            if messages.count >= 2 { // At least one user and one assistant message
                saveCurrentConversation()
            }
        }
        
        // Generate response using AI Inference Manager
        Task {
            await generateAIResponse(for: content, using: model)
        }
    }
    
    // MARK: - AI Response Generation
    @MainActor
    private func generateAIResponse(for userMessage: String, using model: AIModel) async {
        print("🤖 Generating real AI response with model: \(model.name)")
        print("🔍 Model details: id=\(model.id), repo=\(model.huggingFaceRepo)")
        print("🔍 Selected model matches: \(selectedModel?.id == model.id)")
        
        // Build conversation context from message history
        let conversationContext = buildConversationContext(currentMessage: userMessage)
        
        // Log conversation start with actual context
        AIResponseLogger.shared.logConversationStart(
            userMessage: userMessage,
            model: model.name,
            contextLength: conversationContext.count
        )
        
        isGenerating = true
        generationError = nil
        
        // Create placeholder assistant message for streaming
        let assistantMessage = ChatMessage(
            content: "",
            role: .assistant,
            timestamp: Date(),
            modelUsed: model.name,
            tokenMetrics: TokenMetrics()
        )
        
        messages.append(assistantMessage)
        let messageIndex = messages.count - 1
        
        do {
            // Check if the inference manager has the model loaded
            if !aiInferenceManager.isModelLoaded {
                print("📥 Model not loaded, loading now...")
                try await aiInferenceManager.loadModel(model)
            }
            
            // Log the full context being sent to the model
            AIResponseLogger.shared.logFullContext(context: conversationContext)
            
            // Use streaming generation with metrics from AIInferenceManager
            var shouldStopGeneration = false
            var accumulatedResponse = ""
            
            let gen = GenerationSettings.shared
            
            // Adjust parameters for very small models
            let modelName = selectedModel?.name.lowercased() ?? ""
            let adjustedTemp = modelName.contains("smollm") ? min(gen.temperature, 0.3) : gen.temperature
            let adjustedMaxTokens = modelName.contains("smollm") ? min(gen.maxOutputTokens, 100) : gen.maxOutputTokens
            
            print("🎛️ Generation settings: maxTokens=\(adjustedMaxTokens), temp=\(adjustedTemp), topP=\(gen.topP)")
            print("🚀 Starting streaming generation with context length: \(conversationContext.count)")
            
            for await response in aiInferenceManager.generateStreamingTextWithMetrics(
                prompt: conversationContext,
                maxTokens: adjustedMaxTokens,
                temperature: adjustedTemp,
                topP: gen.topP
            ) {
                // Log each streaming chunk with full details
                AIResponseLogger.shared.logStreamingChunk(
                    chunk: response.text,
                    accumulatedLength: accumulatedResponse.count + response.text.count,
                    tokenCount: response.metrics.totalTokens,
                    tokensPerSecond: response.metrics.currentTokensPerSecond
                )
                
                // Accumulate the full response to check for patterns
                accumulatedResponse += response.text
                
                var foundPattern = false
                
                // Check for problematic patterns in the response
                let hasMathPattern = accumulatedResponse.contains("$") || 
                                   accumulatedResponse.contains("\\") ||
                                   accumulatedResponse.contains("lim_") ||
                                   accumulatedResponse.contains("sum_") ||
                                   accumulatedResponse.contains("cos") ||
                                   accumulatedResponse.contains("cdots")
                
                let hasSelfConversation = accumulatedResponse.contains("\n\nUser:") || accumulatedResponse.contains("\nUser:")
                
                // Stop generation if we detect mathematical gibberish or self-conversation
                if hasMathPattern || hasSelfConversation {
                    foundPattern = true
                    shouldStopGeneration = true
                    
                    print("🚨 Detected problematic pattern - stopping generation")
                    print("   Math pattern: \(hasMathPattern)")
                    print("   Self conversation: \(hasSelfConversation)")
                    print("   Response so far: \(String(accumulatedResponse.prefix(200)))...")
                    
                    var cleanedText = accumulatedResponse
                    
                    // If it's mathematical gibberish, provide a helpful response instead
                    if hasMathPattern {
                        cleanedText = "I apologize, but I seem to be having trouble generating a proper response. Could you please try rephrasing your question or try a different model?"
                    } else {
                        // Extract text before the User: marker for self-conversation
                        let patterns = ["\n\nUser:", "\nUser:"]
                        for pattern in patterns {
                            if let range = cleanedText.range(of: pattern) {
                                cleanedText = String(cleanedText[..<range.lowerBound])
                                break
                            }
                        }
                    }
                    
                    // Remove any leading "\n\nAssistant:" or similar patterns from the response
                    let prefixPatterns = ["\n\nAssistant:", "\nAssistant:", "Assistant:"]
                    for prefix in prefixPatterns {
                        if cleanedText.hasPrefix(prefix) {
                            cleanedText = String(cleanedText.dropFirst(prefix.count))
                            break
                        }
                    }
                    
                    cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    await MainActor.run {
                        if messageIndex < messages.count {
                            if !cleanedText.isEmpty {
                                messages[messageIndex].content = cleanedText
                            } else {
                                messages[messageIndex].content = "I'm having trouble generating a proper response. Please try again with a different model."
                            }
                            messages[messageIndex].tokenMetrics = response.metrics
                        }
                    }
                }
                
                if shouldStopGeneration || foundPattern {
                    break
                }
                
                // For normal streaming (no self-conversation detected)
                // Update the message with the new chunk of text
                await MainActor.run {
                    if messageIndex < messages.count && !shouldStopGeneration {
                        // Clear and set the full accumulated response
                        messages[messageIndex].content = accumulatedResponse
                        
                        // Remove any leading Assistant: prefix that might be included
                        let prefixPatterns = ["\n\nAssistant:", "\nAssistant:", "Assistant:"]
                        for prefix in prefixPatterns {
                            if messages[messageIndex].content.hasPrefix(prefix) {
                                messages[messageIndex].content = String(messages[messageIndex].content.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                                break
                            }
                        }
                        
                        messages[messageIndex].tokenMetrics = response.metrics
                    }
                }
            }
            
            // Clean up the final message by trimming trailing whitespace
            await MainActor.run {
                if messageIndex < messages.count {
                    messages[messageIndex].content = messages[messageIndex].content.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Log the complete final response
                    if let finalMetrics = messages[messageIndex].tokenMetrics {
                        AIResponseLogger.shared.logFinalResponse(
                            fullResponse: messages[messageIndex].content,
                            metrics: finalMetrics,
                            model: model.name
                        )
                    }
                }
            }
            
            print("✅ AI response generation completed")
            
        } catch {
            print("❌ Error generating AI response: \(error)")
            
            // Log the error with full context
            AIResponseLogger.shared.logError(
                error: error,
                context: "AI Response Generation",
                model: model.name
            )
            
            await MainActor.run {
                generationError = "Failed to generate response: \(error.localizedDescription)"
                
                // Update message with error state
                if messageIndex < messages.count {
                    messages[messageIndex].content = "Sorry, I encountered an error while generating a response. Please try again."
                }
            }
        }
        
        // Auto-save conversation after response
        saveCurrentConversation()
        
        isGenerating = false
    }
    
    // MARK: - Conversation Context Building
    private func buildConversationContext(currentMessage: String) -> String {
        // Build a simple, reliable context that works across all models
        // Strategy: Use a clean, universal format that doesn't trigger model-specific issues
        
        let globalSystem = GenerationSettings.shared.systemPrompt
        let systemPrompt = globalSystem.isEmpty ? "You are a helpful AI assistant." : globalSystem

        // Determine token budget
        let modelMax = selectedModel?.maxContextTokens ?? 2048
        let responseBuffer = 300 // leave more room for model output
        var availableTokens = max(200, modelMax - responseBuffer)

        // Respect custom context setting when not using max context
        if !useMaxContext {
            let customBudget = max(100, customContextSize * 100) // rough token cap
            availableTokens = min(availableTokens, customBudget)
        }

        // Start with system prompt tokens
        var estimatedTokens = estimateTokenCount(systemPrompt)
        var includedMessages: [ChatMessage] = []

        print("🔍 Total messages in history: \(messages.count)")
        print("🔍 Available tokens for context: \(availableTokens)")
        
        // Walk backwards through history to include as many messages as fit
        for message in messages.reversed() {
            let candidateTokens = estimateTokenCount(message.content) + 10 // margin per message
            print("🔍 Considering message: \(message.role.rawValue) - \(String(message.content.prefix(50)))... (\(candidateTokens) tokens)")
            
            if estimatedTokens + candidateTokens <= availableTokens {
                includedMessages.insert(message, at: 0)
                estimatedTokens += candidateTokens
                print("✅ Included message in context")
            } else {
                print("❌ Message would exceed token limit, stopping")
                break
            }
        }

        // Build context using a simple, universal format
        var context = ""
        
        // Check if this is a very small model that needs extra simple formatting
        let modelName = selectedModel?.name.lowercased() ?? ""
        let modelId = selectedModel?.id.lowercased() ?? ""
        let isVerySmallModel = modelName.contains("smollm") || modelName.contains("135m") || modelName.contains("160m") || modelId.contains("smollm")
        
        print("🤖 Model info: name='\(modelName)', id='\(modelId)', isVerySmall=\(isVerySmallModel)")
        
        if isVerySmallModel {
            // For very small models, use the most minimal format possible
            // Just the user message without complex formatting
            if let lastMessage = includedMessages.last, lastMessage.role == .user {
                context = lastMessage.content
            } else {
                context = currentMessage
            }
        } else {
            // Standard format for larger models
            // Add system prompt if we have one
            if !systemPrompt.isEmpty {
                context += systemPrompt + "\n\n"
            }
            
            // Add conversation history in a clean format
            for message in includedMessages {
                switch message.role {
                case .user:
                    context += "Human: " + message.content + "\n"
                case .assistant:
                    context += "Assistant: " + message.content + "\n"
                case .system:
                    // Skip additional system messages to avoid confusion
                    continue
                }
            }
            
            // Add the final prompt cue
            context += "Assistant:"
        }

        // Ensure we have valid context
        if context.isEmpty {
            context = "Question: " + currentMessage + "\nAnswer:"
            print("⚠️ Context was empty, using fallback format")
        }
        
        // Additional safety check - ensure context is reasonable
        if context.count < 10 {
            context = "Human: " + currentMessage + "\nAssistant:"
            print("⚠️ Context was too short, using safe fallback")
        }
        
        print("📝 Built conversation context (universal format)")
        print("📏 Context length: \(context.count) characters, est tokens: \(estimatedTokens)/\(modelMax)")
        print("💬 Messages included: \(includedMessages.count)")
        print("🔍 Context preview: \(String(context.prefix(200)))...")
        print("🔍 Full context being sent to model:")
        print(String(repeating: "=", count: 50))
        print(context)
        print(String(repeating: "=", count: 50))

        return context
    }
    
    // Simple token estimation (approximately 4 characters per token)
    private func estimateTokenCount(_ text: String) -> Int {
        // This is a rough estimate - actual tokenization varies by model
        // Most models average around 3-4 characters per token
        return max(1, text.count / 4)
    }
}