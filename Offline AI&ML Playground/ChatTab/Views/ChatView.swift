//
//  ChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

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
public struct ChatMessage: Identifiable, Codable {
    public var id = UUID()
    public var content: String
    public let role: MessageRole
    public let timestamp: Date
    
    public let modelUsed: String?
    public var tokenMetrics: TokenMetrics?
    
    public init(content: String, role: MessageRole, timestamp: Date = Date(), modelUsed: String? = nil, tokenMetrics: TokenMetrics? = nil) {
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.modelUsed = modelUsed
        self.tokenMetrics = tokenMetrics
    }
    
    public enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
}


// MARK: - Main Chat View

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ChatViewModel()
    @State private var inputText = ""
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
            
            // Memory indicator
            if !viewModel.messages.isEmpty {
                HStack {
                    Image(systemName: "brain")
                        .foregroundStyle(.secondary)
                    if viewModel.useMaxContext {
                        if let model = viewModel.selectedModel {
                            Text("Memory: Using full context (\(model.maxContextTokens) tokens)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Memory: Last \(min(viewModel.customContextSize, viewModel.messages.count)) messages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
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
                onFocusChanged: { _ in }
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
                    
                    Menu {
                        if viewModel.useMaxContext {
                            Text("Using full model context")
                                .font(.caption)
                            if let model = viewModel.selectedModel {
                                Text("\(model.maxContextTokens) tokens available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Custom limit: \(viewModel.customContextSize) messages")
                                .font(.caption)
                        }
                        
                        Divider()
                        
                        Button {
                            HapticFeedback.light()
                            viewModel.useMaxContext = true
                        } label: {
                            HStack {
                                Text("Use Maximum Context")
                                if viewModel.useMaxContext {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Divider()
                        
                        ForEach([5, 10, 20, 50], id: \.self) { size in
                            Button {
                                HapticFeedback.light()
                                viewModel.useMaxContext = false
                                viewModel.customContextSize = size
                            } label: {
                                HStack {
                                    Text("Limit to \(size) messages")
                                    if !viewModel.useMaxContext && viewModel.customContextSize == size {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Memory Settings", systemImage: "brain")
                    }
                    
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
            ModelPickerView(chatViewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingChatHistory) {
            ChatHistoryView(
                viewModel: ChatHistoryViewModel(modelContext: modelContext),
                onLoadConversation: { conversation in
                    viewModel.loadConversation(conversation)
                }
            )
        }
        .onAppear {
            viewModel.setupHistoryManager(modelContext)
            viewModel.refreshDownloadedModels()
        }
        .onDisappear {
            // Auto-save when leaving the view
            viewModel.saveCurrentConversation()
        }
        .onChange(of: viewModel.showingModelPicker) { oldValue, newValue in
            if !newValue && viewModel.shouldNavigateToDownloads {
                selectedTab = .download
                viewModel.shouldNavigateToDownloads = false
            }
        }
        .onChange(of: viewModel.shouldNavigateToDownloads) { oldValue, newValue in
            if newValue {
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
            if isScrollingUp && scrollDelta > 50 {
                hideKeyboard()
            }
            
            lastScrollPosition = currentPosition
            scrollPosition = currentPosition
        }
    }
    
    private func hideKeyboard() {
        isInputFocused = false
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
