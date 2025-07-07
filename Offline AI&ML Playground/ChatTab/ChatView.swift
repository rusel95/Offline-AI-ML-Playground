//
//  ChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let content: String
    let role: MessageRole
    let timestamp: Date
    let modelUsed: String?
    
    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
}

// MARK: - Chat View Model

@MainActor
class SimpleChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var selectedModel: AIModel?
    @Published var generationError: String?
    @Published var showingModelPicker = false
    @Published var showingChatHistory = false
    @Published var isGenerating = false
    @Published var currentConversation: Conversation?
    @Published var conversationTitle: String = "New Conversation"
    
    // Reference to download manager to get available models
    let downloadManager = ModelDownloadManager()
    
    // AI Inference Manager for real on-device inference
    let aiInferenceManager = AIInferenceManager()
    
    // Chat History Manager
    var historyManager: ChatHistoryManager?
    
    init() {
        downloadManager.loadDownloadedModels()
        downloadManager.refreshAvailableModels()
        
        // Set the first downloaded model as default if available
        let downloadedModels = downloadManager.getDownloadedModels()
        if let firstModel = downloadedModels.first {
            selectedModel = firstModel
            
            // Load the model for inference
            Task {
                await loadModelForInference(firstModel)
            }
        }
    }
    
    func setupHistoryManager(_ modelContext: ModelContext) {
        historyManager = ChatHistoryManager(modelContext: modelContext)
    }
    
    var modelDisplayName: String {
        selectedModel?.name ?? "No model loaded"
    }
    
    var availableModels: [AIModel] {
        downloadManager.getDownloadedModels()
    }
    
    func selectModel(_ model: AIModel) {
        selectedModel = model
        showingModelPicker = false
        
        // Load the new model for inference
        Task {
            await loadModelForInference(model)
        }
    }
    
    /// Load a model for inference
    /// - Parameter model: The AI model to load
    func loadModelForInference(_ model: AIModel) async {
        print("🔄 Loading model for inference: \(model.name)")
        
        do {
            try await aiInferenceManager.loadModel(model)
            print("✅ Model loaded successfully for inference")
        } catch {
            print("❌ Failed to load model for inference: \(error)")
            await MainActor.run {
                generationError = "Failed to load model: \(error.localizedDescription)"
            }
        }
    }
    
    func refreshDownloadedModels() {
        downloadManager.loadDownloadedModels()
        downloadManager.refreshAvailableModels()
        
        let downloadedModels = downloadManager.getDownloadedModels()
        
        // If currently selected model is no longer available, clear selection
        if let selectedModel = selectedModel,
           !downloadedModels.contains(where: { $0.id == selectedModel.id }) {
            self.selectedModel = downloadedModels.first
            
            // Load the new model for inference
            if let newModel = self.selectedModel {
                Task {
                    await loadModelForInference(newModel)
                }
            }
        }
        
        // If no model selected but models are available, select first one
        if selectedModel == nil && !downloadedModels.isEmpty {
            selectedModel = downloadedModels.first
            
            // Load the model for inference
            if let newModel = selectedModel {
                Task {
                    await loadModelForInference(newModel)
                }
            }
        }
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
        
        // Set the model used in this conversation if available
        if let modelName = conversation.modelUsed,
           let model = availableModels.first(where: { $0.name == modelName }) {
            selectedModel = model
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
            await generateRealAIResponse(for: content, using: model)
        }
    }
    
    /// Generate AI response using the AI Inference Manager
    /// - Parameters:
    ///   - userMessage: The user's message
    ///   - model: The AI model to use for generation
    @MainActor
    private func generateRealAIResponse(for userMessage: String, using model: AIModel) async {
        print("🤖 Generating real AI response with model: \(model.name)")
        
        isGenerating = true
        generationError = nil
        
        do {
            // Check if the inference manager has the model loaded
            if !aiInferenceManager.isModelLoaded {
                print("📥 Model not loaded, loading now...")
                try await aiInferenceManager.loadModel(model)
            }
            
            // Create placeholder assistant message for streaming
            let assistantMessage = ChatMessage(
                content: "",
                role: .assistant,
                timestamp: Date(),
                modelUsed: model.name
            )
            
            messages.append(assistantMessage)
            let messageIndex = messages.count - 1
            
            // Generate response using streaming for better UX
            var fullResponse = ""
            
            for await chunk in aiInferenceManager.generateStreamingText(
                prompt: userMessage,
                maxTokens: 512,
                temperature: 0.7
            ) {
                // Since we fixed the streaming to only send new tokens, just append
                fullResponse += chunk
                
                // Update the message content in real-time
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
            
            // Auto-save conversation after response
            saveCurrentConversation()
            
        } catch {
            print("❌ Error generating AI response: \(error)")
            
            // Create error message
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
    
    @MainActor
    private func generateResponse(for userMessage: String, using model: AIModel) async {
        isGenerating = true
        generationError = nil
        
        do {
            let response = try await generateModelResponse(userMessage: userMessage, model: model)
            
            let assistantMessage = ChatMessage(
                content: response,
                role: .assistant,
                timestamp: Date(),
                modelUsed: model.name
            )
            messages.append(assistantMessage)
            
        } catch {
            generationError = "Failed to generate response: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    private func generateModelResponse(userMessage: String, model: AIModel) async throws -> String {
        // Simulate AI model response generation
        // In a real implementation, this would interface with the actual AI model
        
        // Add a realistic delay to simulate model processing
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Generate a response based on the model type
        let response = switch model.type {
        case .llama:
            generateLlamaResponse(for: userMessage, model: model)
        case .code:
            generateCodeResponse(for: userMessage, model: model)
        case .general:
            generateGeneralResponse(for: userMessage, model: model)
        default:
            generateDefaultResponse(for: userMessage, model: model)
        }
        
        return response
    }
    
    private func generateLlamaResponse(for message: String, model: AIModel) -> String {
        // Llama-style response
        let responses = [
            "🦙 As a Llama model, I understand you're asking about \"\(message)\". Let me provide a thoughtful response based on my training.",
            "🦙 That's an interesting question about \"\(message)\". From my understanding, I can share these insights...",
            "🦙 I'm processing your message about \"\(message)\" using my language model capabilities. Here's what I think...",
            "🦙 Your question regarding \"\(message)\" is fascinating. Let me break this down for you..."
        ]
        return responses.randomElement() ?? "🦙 I'm thinking about your message..."
    }
    
    private func generateCodeResponse(for message: String, model: AIModel) -> String {
        // Code model response
        let responses = [
            "💻 As a code-focused model, I can help you with \"\(message)\". Here's my analysis:\n\n```\n// Code example related to your query\nfunction example() {\n    // Implementation here\n}\n```",
            "💻 Looking at your code-related question about \"\(message)\", I suggest the following approach...",
            "💻 I can help you with \"\(message)\". Let me provide a technical solution:\n\n```swift\n// Swift example\nfunc solution() {\n    // Your implementation\n}\n```",
            "💻 Your programming question about \"\(message)\" is interesting. Here's how I'd approach it..."
        ]
        return responses.randomElement() ?? "💻 Let me analyze your code question..."
    }
    
    private func generateGeneralResponse(for message: String, model: AIModel) -> String {
        // General model response
        let responses = [
            "I understand you're asking about \"\(message)\". This is a broad topic that I can help explain...",
            "That's a great question about \"\(message)\". Let me provide a comprehensive answer...",
            "Regarding \"\(message)\", there are several important aspects to consider...",
            "I'd be happy to help you understand \"\(message)\". Here's my perspective..."
        ]
        return responses.randomElement() ?? "I'm processing your question..."
    }
    
    private func generateDefaultResponse(for message: String, model: AIModel) -> String {
        // Default response for other model types
        return "Using \(model.name) (\(model.type.rawValue)) to respond: I understand you're asking about \"\(message)\". This is a \(model.type.rawValue) model, so my response is tailored accordingly."
    }
}

// MARK: - Main Chat View

struct SimpleChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = SimpleChatViewModel()
    @State private var inputText = ""
    @State private var isKeyboardVisible = false
    @State private var lastScrollPosition: CGFloat = 0
    @State private var scrollPosition: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Model selection header
            if viewModel.selectedModel != nil {
                ModelSelectionHeader(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.messages.isEmpty {
                            EmptyStateView(viewModel: viewModel)
                        } else {
                            ForEach(viewModel.messages) { message in
                                ChatMessageView(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isGenerating {
                                TypingIndicatorView(modelName: viewModel.selectedModel?.name ?? "AI Model")
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: geometry.frame(in: .named("scrollView")).minY
                                )
                        }
                    )
                }
                .coordinateSpace(name: "scrollView")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    handleScrollPositionChange(value)
                }
                .onTapGesture {
                    // Tap anywhere in chat to hide keyboard
                    hideKeyboard()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        
                        // Reset scroll position when scrolling to bottom
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            lastScrollPosition = 0
                            scrollPosition = 0
                        }
                    }
                }
            }
            
            // Error display
            if let error = viewModel.generationError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.generationError = nil
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            
            // Input area
            ChatInputView(
                text: $inputText,
                canSend: !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isGenerating && viewModel.selectedModel != nil,
                isGenerating: viewModel.isGenerating,
                onSend: {
                    let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !message.isEmpty {
                        viewModel.sendMessage(message)
                        inputText = ""
                        hideKeyboard()
                    }
                },
                onFocusChanged: { focused in
                    isKeyboardVisible = focused
                }
            )
        }
        .toolbar {
            // Chat History button
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    viewModel.showingChatHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                }
                .disabled(viewModel.isGenerating)
            }
            
            // New Chat button
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.startNewConversation()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.message")
                        Text("New Chat")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                }
                .disabled(viewModel.isGenerating)
            }
            
            // Secondary actions menu
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.startNewConversation()
                    } label: {
                        Label("New Conversation", systemImage: "plus.message")
                    }
                    
                    Button {
                        viewModel.showingChatHistory = true
                    } label: {
                        Label("Chat History", systemImage: "clock.arrow.circlepath")
                    }
                    
                    Divider()
                    
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
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingModelPicker) {
            ModelPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingChatHistory) {
            ChatHistoryView(modelContext: modelContext) { conversation in
                viewModel.loadConversation(conversation)
            }
        }
        .onAppear {
            viewModel.setupHistoryManager(modelContext)
            viewModel.refreshDownloadedModels()
        }
        .onDisappear {
            // Auto-save when leaving the view
            viewModel.saveCurrentConversation()
        }
        .onChange(of: inputText) { _, newText in
            // Show keyboard when user starts typing
            if !newText.isEmpty && !isKeyboardVisible {
                showKeyboard()
            }
        }
        .navigationTitle(viewModel.conversationTitle)
    }
    
    // MARK: - Keyboard Management Methods
    
    private func handleScrollPositionChange(_ value: CGFloat) {
        let currentPosition = value
        
        // Detect scroll direction
        let isScrollingUp = currentPosition > lastScrollPosition
        
        // Hide keyboard when scrolling up (viewing history)
        if isScrollingUp && abs(currentPosition - lastScrollPosition) > 5 {
            hideKeyboard()
        }
        
        // Update positions
        lastScrollPosition = currentPosition
        scrollPosition = currentPosition
    }
    
    private func hideKeyboard() {
        isInputFocused = false
        isKeyboardVisible = false
    }
    
    private func showKeyboard() {
        isInputFocused = true
        isKeyboardVisible = true
    }
}

// MARK: - ScrollOffsetPreferenceKey

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, StoredChatMessage.self, configurations: config)
    
    return SimpleChatView()
        .modelContainer(container)
} 
