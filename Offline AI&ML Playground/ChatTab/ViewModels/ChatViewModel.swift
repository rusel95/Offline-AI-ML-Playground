//
//  ChatViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Chat View Model
/// Main view model for the chat interface
/// Manages chat state, model selection, message generation, and conversation history
@MainActor
class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var selectedModel: AIModel? {
        didSet {
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
    
    // MARK: - Services
    private let chatService: ChatServiceProtocol
    private let chatHistoryService: ChatHistoryServiceProtocol
    private let modelManagementService: ModelManagementServiceProtocol
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var modelDisplayName: String {
        selectedModel?.name ?? "No model loaded"
    }
    
    var availableModels: [AIModel] {
        modelManagementService.getDownloadedModels()
    }
    
    var hasSavedModelPreference: Bool {
        return UserDefaults.standard.lastSelectedModelID != nil
    }
    
    var savedModelID: String? {
        return UserDefaults.standard.lastSelectedModelID
    }
    
    // MARK: - Initialization
    init(
        chatService: ChatServiceProtocol,
        chatHistoryService: ChatHistoryServiceProtocol,
        modelManagementService: ModelManagementServiceProtocol
    ) {
        self.chatService = chatService
        self.chatHistoryService = chatHistoryService
        self.modelManagementService = modelManagementService
        
        setupInitialModel()
    }
    
    convenience init() {
        self.init(
            chatService: AIInferenceManager(),
            chatHistoryService: ChatHistoryManager(),
            modelManagementService: ModelDownloadManager()
        )
    }
    
    // MARK: - Setup Methods
    private func setupInitialModel() {
        modelManagementService.loadDownloadedModels()
        Task {
            await modelManagementService.refreshAvailableModels()
        }
        
        let downloadedModels = modelManagementService.getDownloadedModels()
        let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
        
        var modelToLoad: AIModel?
        
        if let savedModelID = lastSelectedModelID,
           let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
            selectedModel = savedModel
            modelToLoad = savedModel
            print("🔄 Restored last selected model: \(savedModel.name)")
        } else if let firstModel = downloadedModels.first {
            selectedModel = firstModel
            modelToLoad = firstModel
            print("🔄 No saved model found, using first available: \(firstModel.name)")
        }
        
        if let model = modelToLoad {
            Task {
                await loadModelForInference(model)
            }
        }
    }
    
    func setupHistoryManager(_ modelContext: ModelContext) {
        chatHistoryService.setupHistoryManager(modelContext)
    }
    
    // MARK: - Model Management
    func loadModelForInference(_ model: AIModel) async {
        guard !isGenerating && !isModelLoading else {
            print("⚠️ Cannot load model: already generating or loading")
            return
        }
        
        isModelLoading = true
        generationError = nil
        
        print("🔄 Loading model for inference: \(model.name)")
        
        do {
            try await chatService.loadModel(model)
            isModelLoading = false
            generationError = nil
            print("✅ Model loaded successfully for inference: \(model.name)")
        } catch {
            isModelLoading = false
            generationError = "Failed to load model: \(error.localizedDescription)"
            selectedModel = nil
            print("❌ Failed to load model for inference: \(error.localizedDescription)")
        }
    }
    
    func selectModel(_ model: AIModel) async {
        guard !isGenerating else {
            print("⚠️ Cannot switch models while generating text")
            return
        }
        
        if selectedModel?.id == model.id {
            print("ℹ️ Model \(model.name) is already selected")
            return
        }
        
        print("🔄 Switching to model: \(model.name)")
        selectedModel = model
        await loadModelForInference(model)
    }
    
    func refreshDownloadedModels() {
        modelManagementService.loadDownloadedModels()
        Task {
            await modelManagementService.refreshAvailableModels()
        }
        
        let downloadedModels = modelManagementService.getDownloadedModels()
        let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
        
        if let selectedModel = selectedModel,
           !downloadedModels.contains(where: { $0.id == selectedModel.id }) {
            if let savedModelID = lastSelectedModelID,
               let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
                self.selectedModel = savedModel
                print("🔄 Current model unavailable, restored saved model: \(savedModel.name)")
                
                Task {
                    await loadModelForInference(savedModel)
                }
            } else {
                self.selectedModel = downloadedModels.first
                print("🔄 No saved model available, using first model")
                
                if let newModel = self.selectedModel {
                    Task {
                        await loadModelForInference(newModel)
                    }
                }
            }
        }
        
        if selectedModel == nil && !downloadedModels.isEmpty {
            if let savedModelID = lastSelectedModelID,
               let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
                selectedModel = savedModel
                print("🔄 Restored saved model on refresh: \(savedModel.name)")
            } else {
                selectedModel = downloadedModels.first
                print("🔄 No saved preference, using first available model")
            }
            
            if let newModel = selectedModel {
                Task {
                    await loadModelForInference(newModel)
                }
            }
        }
    }
    
    // MARK: - Model Persistence Methods
    func clearSavedModelPreference() {
        UserDefaults.standard.lastSelectedModelID = nil
        print("🗑️ Cleared saved model preference")
    }
    
    // MARK: - Chat History Methods
    func startNewConversation() {
        if !messages.isEmpty {
            saveCurrentConversation()
        }
        
        messages.removeAll()
        currentConversation = nil
        conversationTitle = "New Conversation"
        generationError = nil
    }
    
    func saveCurrentConversation() {
        guard !messages.isEmpty else { return }
        
        if let existing = currentConversation {
            currentConversation = chatHistoryService.saveConversation(
                messages,
                title: conversationTitle,
                existingConversation: existing
            )
        } else {
            currentConversation = chatHistoryService.saveConversation(
                messages,
                title: nil,
                existingConversation: nil
            )
            conversationTitle = currentConversation?.title ?? "New Conversation"
        }
        
        print("💾 Conversation saved: \(conversationTitle)")
    }
    
    func loadConversation(_ conversation: Conversation) async {
        if !messages.isEmpty && currentConversation?.id != conversation.id {
            saveCurrentConversation()
        }
        
        messages = await chatHistoryService.loadConversation(conversation)
        currentConversation = conversation
        conversationTitle = conversation.title
        
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
        
        let userMessage = ChatMessage(
            content: content,
            role: .user,
            timestamp: Date(),
            modelUsed: nil
        )
        messages.append(userMessage)
        
        defer {
            if messages.count >= 2 {
                saveCurrentConversation()
            }
        }
        
        Task {
            await generateRealAIResponse(for: content, using: model)
        }
    }
    
    private func generateRealAIResponse(for userMessage: String, using model: AIModel) async {
        print("🤖 Generating real AI response with model: \(model.name)")
        
        isGenerating = true
        generationError = nil
        
        do {
            if !chatService.isModelLoaded {
                print("📥 Model not loaded, loading now...")
                try await chatService.loadModel(model)
            }
            
            let assistantMessage = ChatMessage(
                content: "",
                role: .assistant,
                timestamp: Date(),
                modelUsed: model.name
            )
            
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1
            
            var fullResponse = ""
            
            for await chunk in chatService.generateStreamingText(
                prompt: userMessage,
                maxTokens: 512,
                temperature: 0.7
            ) {
                fullResponse += chunk
                
                if messageIndex < messages.count {
                    messages[messageIndex] = ChatMessage(
                        content: fullResponse,
                        role: .assistant,
                        timestamp: assistantMessage.timestamp,
                        modelUsed: model.name
                    )
                }
            }
            
            print("✅ AI response generated successfully")
            saveCurrentConversation()
            
        } catch {
            print("❌ Error generating AI response: \(error)")
            
            let errorMessage = ChatMessage(
                content: "Sorry, I encountered an error while generating a response: \(error.localizedDescription)",
                role: .assistant,
                timestamp: Date(),
                modelUsed: model.name
            )
            
            messages.append(errorMessage)
            generationError = error.localizedDescription
        }
        
        isGenerating = false
    }
}

// MARK: - Preview Helper
class MockChatViewModel: ChatViewModel {
    override init() {
        super.init(
            chatService: MockChatService(),
            chatHistoryService: MockChatHistoryService(),
            modelManagementService: MockModelManagementService()
        )
    }
}

#Preview("Chat View Model") {
    VStack(spacing: 20) {
        Text("Chat View Model")
            .font(.title)
            .fontWeight(.bold)
        
        Text("This view model manages:")
            .font(.subheadline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("• Chat messages and conversation state")
            Text("• Model selection and loading")
            Text("• AI response generation")
            Text("• Conversation history management")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        
        // Demo the view model
        let viewModel = MockChatViewModel()
        Text("Demo: \(viewModel.modelDisplayName)")
            .font(.caption)
            .padding()
            .background(.blue.opacity(0.1))
            .cornerRadius(8)
    }
    .padding()
} 