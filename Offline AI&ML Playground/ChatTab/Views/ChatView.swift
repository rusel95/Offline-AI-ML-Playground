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
    var content: String
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
    
    // Reference to shared manager for unified state
    let sharedManager = SharedModelManager.shared
    
    // AI Inference Manager for real on-device inference (simplified mode)
    let aiInferenceManager = AIInferenceManager()
    
    // Chat History Manager
    var historyManager: ChatHistoryManager?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Start model synchronization
        sharedManager.synchronizeModels()
        
        // Set up reactive model loading after synchronization completes
        setupModelLoadingObserver()
    }
    
    private func setupModelLoadingObserver() {
        // Observe changes to downloadedModels to handle model restoration after sync
        sharedManager.$downloadedModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] downloadedModelIds in
                guard let self = self else { return }
                
                // Only proceed if we don't already have a selected model and there are downloaded models
                guard self.selectedModel == nil && !downloadedModelIds.isEmpty else { return }
                
                self.restoreOrSelectDefaultModel()
            }
            .store(in: &cancellables)
    }
    
    private func restoreOrSelectDefaultModel() {
        let downloadedModels = sharedManager.getDownloadedModels()
        let lastSelectedModelID = UserDefaults.standard.lastSelectedModelID
        
        var modelToLoad: AIModel?
        
        // First priority: Try to find the previously selected model
        if let savedModelID = lastSelectedModelID,
           let savedModel = downloadedModels.first(where: { $0.id == savedModelID }) {
            // Check if the saved model is a vision or embedding model that should be filtered out
            if savedModel.name.lowercased().contains("mobilevit") ||
               savedModel.name.lowercased().contains("vision") ||
               savedModel.tags.contains("vision") ||
               savedModel.name.lowercased().contains("minilm") ||
               savedModel.name.lowercased().contains("embedding") ||
               savedModel.name.lowercased().contains("sentence") ||
               savedModel.tags.contains("embedding") ||
               savedModel.tags.contains("sentence-transformers") {
                print("⚠️ Saved model is a vision or embedding model, will use fallback")
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
        // Use the filtered language models from shared manager
        return sharedManager.getAvailableLanguageModels()
    }
    
    /// Load a model for inference with proper loading indicator
    func loadModelForInference(_ model: AIModel) async {
        // Prevent concurrent model loading
        guard !isGenerating && !isModelLoading else {
            print("⚠️ Cannot load model: already generating or loading")
            return
        }
        
        // **CRITICAL**: Ensure model is actually downloaded locally before attempting to load
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
            // This should NEVER trigger a download since we verified the model exists locally
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
        sharedManager.synchronizeModels()
        
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
                        if savedModel.name.lowercased().contains("mobilevit") ||
                           savedModel.name.lowercased().contains("vision") ||
                           savedModel.tags.contains("vision") ||
                           savedModel.name.lowercased().contains("minilm") ||
                           savedModel.name.lowercased().contains("embedding") ||
                           savedModel.name.lowercased().contains("sentence") ||
                           savedModel.tags.contains("embedding") ||
                           savedModel.tags.contains("sentence-transformers") {
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
            // Optimized Chat messages with better performance
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            EmptyStateView(viewModel: viewModel)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        } else {
                            // Optimized message rendering with better memory management
                            ForEach(viewModel.messages.indices, id: \.self) { index in
                                let message = viewModel.messages[index]
                                ChatMessageView(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                            
                            // Typing indicator with better performance
                            if viewModel.isGenerating {
                                TypingIndicatorView(modelName: viewModel.selectedModel?.name ?? "AI Model")
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .background(
                        // Simplified geometry reader for better performance
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
                    // Throttled scroll position handling
                    handleScrollPositionChange(value)
                }
                .simultaneousGesture(
                    // More efficient tap gesture handling
                    TapGesture()
                        .onEnded { _ in
                            hideKeyboard()
                        }
                )
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    // Optimized auto-scroll behavior
                    if newCount > oldCount, let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                // Monitor content changes for streaming updates
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    // Auto-scroll during streaming with debouncing
                    if viewModel.isGenerating, let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
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
            // Optimized Chat History button (leading)
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticFeedback.selectionChanged()
                    viewModel.showingChatHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.bounce, value: viewModel.showingChatHistory)
                }
                .disabled(viewModel.isGenerating || viewModel.isModelLoading)
            }
            
            // Enhanced Model picker button (center/principal)
            ToolbarItem(placement: .principal) {
                Button {
                    if !viewModel.isModelLoading {
                        HapticFeedback.selectionChanged()
                        viewModel.showingModelPicker = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isModelLoading {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.secondary)
                            Text("Loading to memory...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        } else {
                            // Model icon with provider-specific styling
                            if let model = viewModel.selectedModel {
                                Image(systemName: model.displayIcon)
                                    .foregroundStyle(model.displayColor)
                                
                                Text(model.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            } else {
                                Image(systemName: "cpu")
                                    .foregroundStyle(.secondary)
                                Text("Select Model")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .foregroundStyle(viewModel.isModelLoading ? .secondary : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                }
                .disabled(viewModel.isGenerating || viewModel.isModelLoading)
            }
            
            // Enhanced Actions menu (trailing)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticFeedback.light()
                        viewModel.startNewConversation()
                    } label: {
                        Label("New Conversation", systemImage: "plus.message")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Button {
                        HapticFeedback.light()
                        viewModel.showingChatHistory = true
                    } label: {
                        Label("Chat History", systemImage: "clock.arrow.circlepath")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Button {
                        if !viewModel.isModelLoading {
                            HapticFeedback.light()
                            viewModel.showingModelPicker = true
                        }
                    } label: {
                        Label("Select Model", systemImage: "cpu")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        HapticFeedback.light()
                        viewModel.clearConversation()
                    } label: {
                        Label("Clear Conversation", systemImage: "trash")
                    }
                    .disabled(viewModel.isModelLoading)
                    
                    Divider()
                    
                    Button {
                        HapticFeedback.light()
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
                        .symbolEffect(.bounce, value: viewModel.showingChatHistory)
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
            // Optimized keyboard handling with debouncing
            if !newText.isEmpty && !isKeyboardVisible {
                showKeyboard()
            }
        }
        // Add haptic feedback for better user experience
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
        .onChange(of: viewModel.showingModelPicker) { oldValue, newValue in
            if !newValue && viewModel.shouldNavigateToDownloads {
                selectedTab = .download
                viewModel.shouldNavigateToDownloads = false
            }
        }
    }
    
    // MARK: - Optimized Keyboard Management Methods
    
    @State private var scrollDebounceTimer: Timer?
    
    private func handleScrollPositionChange(_ value: CGFloat) {
        let currentPosition = value
        
        // Throttle scroll position updates for better performance
        scrollDebounceTimer?.invalidate()
        scrollDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { _ in
            let isScrollingUp = currentPosition > lastScrollPosition
            let scrollDelta = abs(currentPosition - lastScrollPosition)
            
            // Only hide keyboard for significant upward scrolls
            if isScrollingUp && scrollDelta > 20 && isKeyboardVisible {
                hideKeyboard()
            }
            
            lastScrollPosition = currentPosition
            scrollPosition = currentPosition
        }
    }
    
    private func hideKeyboard() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isInputFocused = false
            isKeyboardVisible = false
        }
    }
    
    private func showKeyboard() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isInputFocused = true
            isKeyboardVisible = true
        }
    }
}

// MARK: - ScrollOffsetPreferenceKey

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Haptic Feedback Helper

struct HapticFeedback {
    static func light() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    static func selectionChanged() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    static func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    static func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
}
