//
//  ChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - UserDefaults Extension for Model Persistence
extension UserDefaults {
    private enum Keys {
        static let lastSelectedModelID = "lastSelectedModelID"
    }
    
    var lastSelectedModelID: String? {
        get { string(forKey: Keys.lastSelectedModelID) }
        set { set(newValue, forKey: Keys.lastSelectedModelID) }
    }
}

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
    
    // Reference to download manager to get available models
    let downloadManager = ModelDownloadManager()
    
    // AI Inference Manager for real on-device inference
    let aiInferenceManager = AIInferenceManager()
    
    // Chat History Manager
    var historyManager: ChatHistoryManager?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        downloadManager.loadDownloadedModels()
        downloadManager.refreshAvailableModels()
        
        // Try to restore the last selected model
        let downloadedModels = downloadManager.getDownloadedModels()
        let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
        
        var modelToLoad: AIModel?
        
        // First priority: Try to find the previously selected model
        if let savedModelID = lastSelectedModelID,
           let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
            // Check if the saved model is a vision model that should be filtered out
            if savedModel.name.lowercased().contains("mobilevit") ||
               savedModel.name.lowercased().contains("vision") ||
               savedModel.tags.contains("vision") {
                print("⚠️ Saved model is a vision model, will use fallback")
                // Don't set this as selected model, will use fallback below
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
    
    func setupHistoryManager(_ modelContext: ModelContext) {
        historyManager = ChatHistoryManager(modelContext: modelContext)
    }
    
    var modelDisplayName: String {
        selectedModel?.name ?? "No model loaded"
    }
    
    var availableModels: [AIModel] {
        // Filter out vision models that can't be used for text generation
        return downloadManager.getDownloadedModels().filter { model in
            !model.name.lowercased().contains("mobilevit") &&
            !model.name.lowercased().contains("vision") &&
            !model.tags.contains("vision")
        }
    }
    
    /// Load a model for inference with proper error handling and race condition prevention
    func loadModelForInference(_ model: AIModel) async {
        // Prevent concurrent model loading
        guard !isGenerating && !isModelLoading else {
            print("⚠️ Cannot load model: already generating or loading")
            return
        }
        
        await MainActor.run {
            isModelLoading = true
            generationError = nil
        }
        
        print("🔄 Loading model for inference: \(model.name)")
        
        do {
            try await aiInferenceManager.loadModel(model)
            await MainActor.run {
                isModelLoading = false
                generationError = nil
            }
            print("✅ Model loaded successfully for inference: \(model.name)")
        } catch {
            await MainActor.run {
                isModelLoading = false
                generationError = "Failed to load model: \(error.localizedDescription)"
                
                // If it's a vision model error, provide more helpful guidance
                if error.localizedDescription.contains("Vision models") {
                    generationError = "Vision models like MobileViT cannot be used for text generation. Please select a language model from the model picker."
                }
                
                selectedModel = nil
            }
            print("❌ Failed to load model for inference: \(error.localizedDescription)")
        }
    }
    
    /// Select a model with proper memory management
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
        downloadManager.loadDownloadedModels()
        downloadManager.refreshAvailableModels()
        
        let downloadedModels = downloadManager.getDownloadedModels()
        let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
        let availableModels = self.availableModels // Use filtered list
        
        // Check if currently selected model is still available
        if let selectedModel = selectedModel,
           !downloadedModels.contains(where: { $0.id == selectedModel.id }) {
            // Current model no longer available, try to restore from UserDefaults
            if let savedModelID = lastSelectedModelID,
               let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
                // Check if saved model is a vision model
                if savedModel.name.lowercased().contains("mobilevit") ||
                   savedModel.name.lowercased().contains("vision") ||
                   savedModel.tags.contains("vision") {
                    print("⚠️ Saved model is a vision model, using fallback")
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
            if let savedModelID = lastSelectedModelID,
               let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
                // Check if saved model is a vision model
                if savedModel.name.lowercased().contains("mobilevit") ||
                   savedModel.name.lowercased().contains("vision") ||
                   savedModel.tags.contains("vision") {
                    print("⚠️ Saved model is a vision model, using fallback")
                    selectedModel = availableModels.first
                    print("🔄 Using first available language model")
                } else {
                    selectedModel = savedModel
                    print("🔄 Restored saved model on refresh: \(savedModel.name)")
                }
            } else {
                selectedModel = availableModels.first
                print("🔄 No saved preference, using first available language model")
            }
            
            // Load the selected model for inference
            if let newModel = selectedModel {
                Task {
                    await loadModelForInference(newModel)
                }
            }
        }
    }
    
    // MARK: - Model Persistence Methods
    
    /// Check if there's a saved model preference
    var hasSavedModelPreference: Bool {
        return UserDefaults.standard.lastSelectedModelID != nil
    }
    
    /// Clear the saved model preference
    func clearSavedModelPreference() {
        UserDefaults.standard.lastSelectedModelID = nil
        print("🗑️ Cleared saved model preference")
    }
    
    /// Get the saved model ID
    var savedModelID: String? {
        return UserDefaults.standard.lastSelectedModelID
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
    @Binding var selectedTab: AppView.Tab

    var body: some View {
        VStack(spacing: 0) {
            // Model selection header
            if viewModel.selectedModel != nil {
                ModelSelectionHeader(viewModel: viewModel)
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
                canSend: !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isGenerating && !viewModel.isModelLoading && viewModel.selectedModel != nil,
                isGenerating: viewModel.isGenerating || viewModel.isModelLoading,
                onSend: {
                    let message = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !message.isEmpty && !viewModel.isModelLoading {
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
            // Chat History button (leading)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.showingChatHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(viewModel.isGenerating || viewModel.isModelLoading)
            }
            
            // Model picker button (center/principal)
            ToolbarItem(placement: .principal) {
                Button {
                    if !viewModel.isModelLoading {
                        viewModel.showingModelPicker = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isModelLoading {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Loading model to memory")
                        } else {
                            Image(systemName: "cpu")
                            Text("\(viewModel.selectedModel?.name ?? "No Model")")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(viewModel.isModelLoading ? .secondary : Color.accentColor)
                }
                .disabled(viewModel.isGenerating || viewModel.isModelLoading)
            }
            
            // Actions menu (trailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.startNewConversation()
                    } label: {
                        Label("New Conversation", systemImage: "plus.message")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Button {
                        viewModel.showingChatHistory = true
                    } label: {
                        Label("Chat History", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Button {
                        if !viewModel.isModelLoading {
                            viewModel.showingModelPicker = true
                        }
                    } label: {
                        Label("Select Model", systemImage: "cpu")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Divider()
                    
                    Button {
                        viewModel.clearConversation()
                    } label: {
                        Label("Clear Conversation", systemImage: "trash")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Divider()
                    
                    Button {
                        viewModel.refreshDownloadedModels()
                    } label: {
                        if viewModel.isModelLoading {
                            Label("Loading Models...", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isModelLoading)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(viewModel.isModelLoading)
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
        .onChange(of: viewModel.showingModelPicker) { oldValue, newValue in
            if !newValue && viewModel.shouldNavigateToDownloads {
                selectedTab = .download
                viewModel.shouldNavigateToDownloads = false
            }
        }
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
    SimpleChatView(selectedTab: .constant(.chat))
        .modelContainer(container)
} 
