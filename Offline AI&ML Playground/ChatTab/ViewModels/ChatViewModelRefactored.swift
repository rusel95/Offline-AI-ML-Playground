//
//  ChatViewModelRefactored.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import SwiftUI
import SwiftData
import Combine

/// Refactored ChatViewModel following SOLID principles
@MainActor
class ChatViewModelRefactored: ObservableObject {
    
    // MARK: - UI State (Single Responsibility)
    @Published var messages: [ChatMessage] = []
    @Published var selectedModel: AIModel?
    @Published var isGenerating = false
    @Published var generationError: String?
    @Published var showingModelPicker = false
    @Published var showingChatHistory = false
    
    // MARK: - Dependencies (Dependency Inversion)
    private let modelCatalog: ModelCatalogProtocol
    private let inferenceService: ModelInferenceProtocol
    private let conversationManager: ConversationManagerProtocol
    private let contextBuilder: ContextBuilderProtocol
    
    // MARK: - Settings
    @Published public var useMaxContext: Bool = true {
        didSet { saveSettings() }
    }
    
    @Published public var customContextSize: Int = 10 {
        didSet { saveSettings() }
    }
    
    // MARK: - Initialization with Dependency Injection
    public init(
        modelCatalog: ModelCatalogProtocol,
        inferenceService: ModelInferenceProtocol,
        conversationManager: ConversationManagerProtocol,
        contextBuilder: ContextBuilderProtocol
    ) {
        self.modelCatalog = modelCatalog
        self.inferenceService = inferenceService
        self.conversationManager = conversationManager
        self.contextBuilder = contextBuilder
        
        loadSettings()
        restoreLastSelectedModel()
    }
    
    // MARK: - Convenience initializer for production
    public convenience init() {
        self.init(
            modelCatalog: ModelCatalog(),
            inferenceService: AIInferenceCoordinator(),
            conversationManager: ConversationManager(),
            contextBuilder: ContextBuilder()
        )
    }
    
    // MARK: - Model Management
    
    public func selectModel(_ model: AIModel) {
        selectedModel = model
        UserDefaults.standard.set(model.id, forKey: "lastSelectedModelID")
    }
    
    public var availableModels: [AIModel] {
        return modelCatalog.availableModels.filter { model in
            // Filter for language models only
            !model.tags.contains("vision") &&
            !model.tags.contains("embedding")
        }
    }
    
    // MARK: - Message Handling
    
    public func sendMessage(_ text: String) async {
        guard let model = selectedModel else {
            generationError = "Please select a model first"
            return
        }
        
        // Add user message
        let userMessage = ChatMessage(
            content: text,
            role: .user,
            timestamp: Date(),
            modelUsed: model.name
        )
        messages.append(userMessage)
        
        // Build context
        let context = contextBuilder.buildContext(
            messages: messages,
            maxTokens: getMaxContextTokens(),
            useFullHistory: useMaxContext
        )
        
        // Generate response
        isGenerating = true
        generationError = nil
        
        do {
            let response = try await inferenceService.generateText(
                prompt: context,
                maxTokens: 512
            )
            
            let assistantMessage = ChatMessage(
                content: response,
                role: .assistant,
                timestamp: Date(),
                modelUsed: model.name
            )
            messages.append(assistantMessage)
            
            // Save to conversation history
            await conversationManager.saveMessage(assistantMessage)
            
        } catch {
            generationError = error.localizedDescription
        }
        
        isGenerating = false
    }
    
    // MARK: - Conversation Management
    
    public func startNewConversation() async {
        messages.removeAll()
        await conversationManager.createNewConversation()
    }
    
    public func loadConversation(_ conversationId: String) async {
        if let loadedMessages = await conversationManager.loadConversation(conversationId) {
            messages = loadedMessages
        }
    }
    
    // MARK: - Private Methods
    
    private func getMaxContextTokens() -> Int {
        if useMaxContext {
            return selectedModel?.maxContextTokens ?? 2048
        } else {
            return customContextSize * 100 // Rough token estimation
        }
    }
    
    private func loadSettings() {
        useMaxContext = UserDefaults.standard.object(forKey: "chatUseMaxContext") as? Bool ?? true
        let savedCustomSize = UserDefaults.standard.integer(forKey: "chatCustomContextSize")
        if savedCustomSize > 0 {
            customContextSize = savedCustomSize
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(useMaxContext, forKey: "chatUseMaxContext")
        UserDefaults.standard.set(customContextSize, forKey: "chatCustomContextSize")
    }
    
    private func restoreLastSelectedModel() {
        if let modelId = UserDefaults.standard.string(forKey: "lastSelectedModelID"),
           let model = modelCatalog.getModel(by: modelId) {
            selectedModel = model
        }
    }
}

// MARK: - Protocol Implementations

/// Manages conversation persistence
protocol ConversationManagerProtocol {
    func createNewConversation() async
    func saveMessage(_ message: ChatMessage) async
    func loadConversation(_ id: String) async -> [ChatMessage]?
}

/// Builds context for AI generation
protocol ContextBuilderProtocol {
    func buildContext(messages: [ChatMessage], maxTokens: Int, useFullHistory: Bool) -> String
}

// MARK: - Concrete Implementations

public class ConversationManager: ConversationManagerProtocol {
    private var currentConversationId: String?
    private var conversations: [String: [ChatMessage]] = [:]
    
    public init() {}
    
    public func createNewConversation() async {
        currentConversationId = UUID().uuidString
        conversations[currentConversationId!] = []
    }
    
    public func saveMessage(_ message: ChatMessage) async {
        guard let conversationId = currentConversationId else { return }
        
        if conversations[conversationId] == nil {
            conversations[conversationId] = []
        }
        conversations[conversationId]?.append(message)
    }
    
    public func loadConversation(_ id: String) async -> [ChatMessage]? {
        currentConversationId = id
        return conversations[id]
    }
}

public class ContextBuilder: ContextBuilderProtocol {
    public init() {}
    
    public func buildContext(messages: [ChatMessage], maxTokens: Int, useFullHistory: Bool) -> String {
        // Build context from messages
        var context = ""
        
        for message in messages {
            let rolePrefix = message.role == .user ? "User: " : "Assistant: "
            context += "\(rolePrefix)\(message.content)\n\n"
        }
        
        return context.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public class ModelCatalog: ModelCatalogProtocol {
    @Published public var availableModels: [AIModel] = []
    
    public init() {
        Task {
            await loadModels()
        }
    }
    
    public func loadModels() async {
        // Load from SharedModelManager
        availableModels = SharedModelManager.shared.getAvailableLanguageModels()
    }
    
    public func searchModels(query: String) -> [AIModel] {
        return availableModels.filter { model in
            model.name.localizedCaseInsensitiveContains(query) ||
            model.description.localizedCaseInsensitiveContains(query)
        }
    }
    
    public func getModel(by id: String) -> AIModel? {
        return availableModels.first { $0.id == id }
    }
}