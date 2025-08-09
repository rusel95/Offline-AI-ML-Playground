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
            
            // Build conversation context from message history
            let conversationContext = buildConversationContext(currentMessage: userMessage)
            
            // Use streaming generation with metrics from AIInferenceManager
            var shouldStopGeneration = false
            var accumulatedResponse = ""
            
            let gen = GenerationSettings.shared
            for await response in aiInferenceManager.generateStreamingTextWithMetrics(
                prompt: conversationContext,
                maxTokens: gen.maxOutputTokens,
                temperature: gen.temperature,
                topP: gen.topP
            ) {
                // Accumulate the full response to check for patterns
                accumulatedResponse += response.text
                
                var foundPattern = false
                
                // Check if accumulated response contains self-conversation patterns
                // Look for patterns that indicate the model is creating a conversation
                if accumulatedResponse.contains("\n\nUser:") || accumulatedResponse.contains("\nUser:") {
                    foundPattern = true
                    shouldStopGeneration = true
                    
                    // Extract text before the User: marker
                    let patterns = ["\n\nUser:", "\nUser:"]
                    var cleanedText = accumulatedResponse
                    
                    for pattern in patterns {
                        if let range = cleanedText.range(of: pattern) {
                            cleanedText = String(cleanedText[..<range.lowerBound])
                            break
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
                }
            }
            
            print("✅ AI response generation completed")
            
        } catch {
            print("❌ Error generating AI response: \(error)")
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
        // Build a token-aware context using full chat history when possible
        // Strategy: include messages from newest to oldest until budget reached, then render with a model-friendly chat template
        let globalSystem = GenerationSettings.shared.systemPrompt
        let systemPrompt = globalSystem.isEmpty ? "You are a helpful AI assistant. Respond naturally and conversationally." : globalSystem

        // Determine token budget
        let modelMax = selectedModel?.maxContextTokens ?? 2048
        let responseBuffer = 200 // leave room for model output
        var availableTokens = max(256, modelMax - responseBuffer)

        // Respect custom context setting when not using max context
        if !useMaxContext {
            let customBudget = max(100, customContextSize * 100) // rough token cap
            availableTokens = min(availableTokens, customBudget)
        }

        // Start with system prompt tokens
        var estimatedTokens = estimateTokenCount(systemPrompt)
        var includedMessages: [ChatMessage] = []

        // Ensure the latest user message is present (it should be already appended before calling this method)
        // Walk backwards through history to include as many messages as fit
        for message in messages.reversed() {
            let rolePrefix = message.role == .user ? "User: " : "Assistant: "
            let candidate = rolePrefix + message.content
            let candidateTokens = estimateTokenCount(candidate) + 2 // margin per turn
            if estimatedTokens + candidateTokens <= availableTokens {
                includedMessages.insert(message, at: 0)
                estimatedTokens += candidateTokens
            } else {
                // Try to include at least a truncated version of the last user message if nothing fits
                if includedMessages.isEmpty, message.role == .user {
                    // Take a suffix of the user message
                    let content = message.content
                    if content.count > 0 {
                        let approxChars = max(40, (availableTokens - estimatedTokens) * 3)
                        let truncated = String(content.suffix(min(content.count, approxChars)))
                        let truncatedMessage = ChatMessage(
                            content: truncated,
                            role: .user,
                            timestamp: message.timestamp,
                            modelUsed: message.modelUsed
                        )
                        includedMessages = [truncatedMessage]
                        estimatedTokens = availableTokens // consume budget
                    }
                }
                break
            }
        }

        // Check if we're using a base model vs an instruction-tuned model
        let modelName = selectedModel?.name.lowercased() ?? ""
        let isInstructModel = modelName.contains("instruct") || modelName.contains("chat") || 
                              modelName.contains("alpaca") || modelName.contains("vicuna")
        
        var context = ""
        
        if isInstructModel {
            // Use instruction format for instruction-tuned models
            if !systemPrompt.isEmpty {
                context += "### System:\n" + systemPrompt + "\n\n"
            }
            for message in includedMessages {
                switch message.role {
                case .user:
                    context += "### Instruction:\n" + message.content + "\n\n"
                case .assistant:
                    context += "### Response:\n" + message.content + "\n\n"
                case .system:
                    context += "### System:\n" + message.content + "\n\n"
                }
            }
            // Final assistant cue
            context += "### Response:\n"
        } else {
            // Use a simpler conversational format for base models
            if !systemPrompt.isEmpty {
                context = systemPrompt + "\n\n"
            }
            
            // Add conversation history in a natural format
            for (index, message) in includedMessages.enumerated() {
                switch message.role {
                case .user:
                    context += "Human: " + message.content + "\n"
                case .assistant:
                    context += "Assistant: " + message.content + "\n"
                case .system:
                    context += message.content + "\n"
                }
                
                // Add spacing between turns except for the last one
                if index < includedMessages.count - 1 {
                    context += "\n"
                }
            }
            
            // Add final prompt
            context += "\nAssistant:"
        }

        print("📝 Built conversation context (model-aware format)")
        print("🤖 Using \(isInstructModel ? "instruction" : "conversational") format for: \(selectedModel?.name ?? "unknown")")
        print("📏 Context length: \(context.count) characters, est tokens: \(estimatedTokens)/\(modelMax)")

        return context
    }
    
    // Simple token estimation (approximately 4 characters per token)
    private func estimateTokenCount(_ text: String) -> Int {
        // This is a rough estimate - actual tokenization varies by model
        // Most models average around 3-4 characters per token
        return max(1, text.count / 4)
    }
}