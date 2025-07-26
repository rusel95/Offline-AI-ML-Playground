//
//  ChatViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import SwiftData
import Combine

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
    
    // MARK: - Dependencies
    private let sharedManager = SharedModelManager.shared
    private let aiInferenceManager = AIInferenceManager()
    private var historyManager: ChatHistoryManager?
    private var cancellables = Set<AnyCancellable>()
    
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
        // ModelFileManager handles synchronization automatically
        // Set up reactive model loading
        setupModelLoadingObserver()
    }
    
    // MARK: - Setup Methods
    func setupHistoryManager(_ modelContext: ModelContext) {
        historyManager = ChatHistoryManager(modelContext: modelContext)
    }
    
    private func setupModelLoadingObserver() {
        // Observe changes to downloadedModels to handle model restoration after sync
        ModelFileManager.shared.$downloadedModels
            .receive(on: RunLoop.main)
            .sink { [weak self] downloadedModelIds in
                guard let self = self else { return }
                
                // Only proceed if we don't already have a selected model and there are downloaded models
                guard self.selectedModel == nil && !downloadedModelIds.isEmpty else { return }
                
                self.restoreOrSelectDefaultModel()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Model Management
    private func restoreOrSelectDefaultModel() {
        let downloadedModels = sharedManager.getDownloadedModels()
        let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
        
        var modelToLoad: AIModel?
        
        // First priority: Try to find the previously selected model
        if let savedModelID = lastSelectedModelID,
           let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
            // Check if the saved model is a vision or embedding model that should be filtered out
            if isVisionOrEmbeddingModel(savedModel) {
                print("⚠️ Saved model is a vision or embedding model, will use fallback")
            } else {
                selectedModel = savedModel
                modelToLoad = savedModel
                print("🔄 Restored last selected model: \(savedModel.name)")
            }
        }
        
        // Fallback: Use the first available model if no saved model found or if saved model was vision
        if modelToLoad == nil {
            let availableModels = self.availableModels // Use the filtered list
            if let firstModel = availableModels.first {
                selectedModel = firstModel
                modelToLoad = firstModel
                print("🔄 Using first available language model: \(firstModel.name)")
            }
        }
        
        // Load the selected model for inference
        if let model = modelToLoad {
            Task {
                await loadModelForInference(model)
            }
        }
    }
    
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
                    else {
                        self.selectedModel = availableModels.first
                        print("🔄 No saved model available, using first language model")
                        
                        if let newModel = self.selectedModel {
                            Task {
                                await loadModelForInference(newModel)
                            }
                        }
                    }
                }
                
                // If no model selected but models are available, try to restore preference
                if selectedModel == nil && !availableModels.isEmpty {
                    self.restoreOrSelectDefaultModel()
                }
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
            modelUsed: model.name
        )
        
        messages.append(assistantMessage)
        let messageIndex = messages.count - 1
        
        do {
            // Check if the inference manager has the model loaded
            if !aiInferenceManager.isModelLoaded {
                print("📥 Model not loaded, loading now...")
                try await aiInferenceManager.loadModel(model)
            }
            
            // Use streaming generation from AIInferenceManager
            for await chunk in aiInferenceManager.generateStreamingText(
                prompt: userMessage,
                maxTokens: 512,
                temperature: 0.7
            ) {
                // Update the message content with streaming text
                await MainActor.run {
                    if messageIndex < messages.count {
                        messages[messageIndex].content += chunk
                    }
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
}