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


// MARK: - Main Chat View

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ChatViewModel()
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
