//
//  ChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Simple Chat Models

struct SimpleChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    
    init(content: String, isUser: Bool, timestamp: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct SimpleChatSession: Identifiable {
    let id: UUID
    var title: String
    var messages: [SimpleChatMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Chat") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func addMessage(_ message: SimpleChatMessage) {
        messages.append(message)
        updatedAt = Date()
        
        // Update title from first user message
        if title == "New Chat" && message.isUser && !message.content.isEmpty {
            title = String(message.content.prefix(30)) + (message.content.count > 30 ? "..." : "")
        }
    }
}

// MARK: - Chat View Model

@MainActor
class SimpleChatViewModel: ObservableObject {
    @Published var currentSession = SimpleChatSession()
    @Published var sessions: [SimpleChatSession] = []
    @Published var messageInput = ""
    @Published var isGenerating = false
    @Published var selectedModel: AIModel?
    @Published var generationError: String?
    @Published var showingModelPicker = false
    
    // Reference to download manager to get available models
    let downloadManager = ModelDownloadManager()
    
    init() {
        downloadManager.loadDownloadedModels()
        downloadManager.refreshAvailableModels()
        
        // Set the first downloaded model as default if available
        let downloadedModels = downloadManager.getDownloadedModels()
        if let firstModel = downloadedModels.first {
            selectedModel = firstModel
        }
    }
    
    var canSendMessage: Bool {
        !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isGenerating &&
        selectedModel != nil
    }
    
    var modelDisplayName: String {
        selectedModel?.name ?? "No model loaded"
    }
    
    var hasMessages: Bool {
        !currentSession.messages.isEmpty
    }
    
    var availableModels: [AIModel] {
        downloadManager.getDownloadedModels()
    }
    
    func selectModel(_ model: AIModel) {
        selectedModel = model
        showingModelPicker = false
    }
    
    func refreshDownloadedModels() {
        downloadManager.loadDownloadedModels()
        downloadManager.refreshAvailableModels()
        
        let downloadedModels = downloadManager.getDownloadedModels()
        
        // If currently selected model is no longer available, clear selection
        if let selectedModel = selectedModel,
           !downloadedModels.contains(where: { $0.id == selectedModel.id }) {
            self.selectedModel = downloadedModels.first
        }
        
        // If no model selected but models are available, select first one
        if selectedModel == nil && !downloadedModels.isEmpty {
            selectedModel = downloadedModels.first
        }
    }
    
    func sendMessage() {
        Task {
            let messageContent = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !messageContent.isEmpty else { return }
            
            // Create user message
            let userMessage = SimpleChatMessage(
                content: messageContent,
                isUser: true,
                timestamp: Date()
            )
            
            // Update state
            currentSession.addMessage(userMessage)
            messageInput = ""
            isGenerating = true
            generationError = nil
            
            do {
                // Simulate AI response with model-specific behavior
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
                let response = generateModelSpecificResponse(for: messageContent)
                
                let assistantMessage = SimpleChatMessage(
                    content: response,
                    isUser: false,
                    timestamp: Date()
                )
                
                currentSession.addMessage(assistantMessage)
                isGenerating = false
                
            } catch {
                isGenerating = false
                generationError = error.localizedDescription
            }
        }
    }
    
    func newSession() {
        currentSession = SimpleChatSession()
        generationError = nil
    }
    
    func clearConversation() {
        currentSession = SimpleChatSession()
        generationError = nil
    }
    
    private func generateModelSpecificResponse(for prompt: String) -> String {
        guard let model = selectedModel else {
            return "No model selected."
        }
        
        let modelName = model.name
        
        if prompt.lowercased().contains("hello") || prompt.lowercased().contains("hi") {
            return "Hello! I'm \(modelName). How can I help you today?"
        } else if prompt.lowercased().contains("how are you") {
            return "I'm \(modelName), and I'm doing well! How can I assist you?"
        } else if prompt.lowercased().contains("code") && model.type == .code {
            return "I'm \(modelName), specialized for coding tasks. I can help you with programming questions, code review, and software development. What would you like to work on?"
        } else if prompt.lowercased().contains("whisper") && model.type == .whisper {
            return "I'm \(modelName), designed for speech recognition and audio processing. How can I assist you with audio-related tasks?"
        } else {
            return "I'm \(modelName). Thank you for your message: \"\(prompt)\". This is a simulated response. In a real implementation, this would be generated by the actual \(modelName) model."
        }
    }
}

// MARK: - Main Chat View

struct ChatView: View {
    @StateObject private var viewModel = SimpleChatViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Model selection header
                ModelSelectionHeader(viewModel: viewModel)
                
                // Messages list
                if viewModel.hasMessages {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.currentSession.messages) { message in
                                    ChatMessageView(message: message)
                                        .id(message.id)
                                }
                                
                                // Typing indicator
                                if viewModel.isGenerating {
                                    TypingIndicatorView(modelName: viewModel.modelDisplayName)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.currentSession.messages.count) { oldValue, newValue in
                            if let lastMessage = viewModel.currentSession.messages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                } else {
                    // Empty state
                    EmptyStateView(viewModel: viewModel)
                }
                
                Divider()
                
                // Input area
                ChatInputView(
                    text: $viewModel.messageInput,
                    canSend: viewModel.canSendMessage,
                    isGenerating: viewModel.isGenerating,
                    onSend: { viewModel.sendMessage() }
                )
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.newSession()
                        } label: {
                            Label("New Chat", systemImage: "plus.message")
                        }
                        
                        Button {
                            viewModel.clearConversation()
                        } label: {
                            Label("Clear Conversation", systemImage: "trash")
                        }
                        
                        Divider()
                        
                        Button {
                            viewModel.refreshDownloadedModels()
                        } label: {
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshDownloadedModels()
        }
        .alert("Generation Error", isPresented: .constant(viewModel.generationError != nil)) {
            Button("OK") {
                viewModel.generationError = nil
            }
        } message: {
            Text(viewModel.generationError ?? "")
        }
        .sheet(isPresented: $viewModel.showingModelPicker) {
            ModelPickerView(viewModel: viewModel)
        }
    }
}









#Preview {
    ChatView()
} 