//
//  iOSChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - iOS Chat View
/// Main chat interface for iOS devices
/// Displays messages, handles input, and manages chat interactions
struct iOSChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var inputText: String
    @Binding var isKeyboardVisible: Bool
    @Binding var lastScrollPosition: CGFloat
    @Binding var scrollPosition: CGFloat
    @FocusState var isInputFocused: Bool
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedModel != nil {
                ModelSelectionHeader(viewModel: viewModel)
                    .padding(.top, 8)
            }
            
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
                    hideKeyboard()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            lastScrollPosition = 0
                            scrollPosition = 0
                        }
                    }
                }
            }
            
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
            
            let canSendMessage = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
                                !viewModel.isGenerating && 
                                !viewModel.isModelLoading && 
                                viewModel.selectedModel != nil
            
            ChatInputView(
                text: $inputText,
                canSend: canSendMessage,
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showingChatHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .disabled(viewModel.isGenerating || viewModel.isModelLoading)
            }
            
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
                            Text("Loading...")
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
            
            ToolbarItem(placement: .secondaryAction) {
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
                Task {
                    await viewModel.loadConversation(conversation)
                }
            }
        }
        .onAppear {
            viewModel.setupHistoryManager(modelContext)
            viewModel.refreshDownloadedModels()
        }
        .onDisappear {
            viewModel.saveCurrentConversation()
        }
        .onChange(of: inputText) { _, newText in
            if !newText.isEmpty && !isKeyboardVisible {
                showKeyboard()
            }
        }
        .navigationTitle(viewModel.conversationTitle)
    }
    
    private func handleScrollPositionChange(_ value: CGFloat) {
        let currentPosition = value
        let isScrollingUp = currentPosition > lastScrollPosition
        
        if isScrollingUp && abs(currentPosition - lastScrollPosition) > 5 {
            hideKeyboard()
        }
        
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

// MARK: - Preview Helper
struct MockiOSChatView: View {
    @StateObject private var viewModel = MockChatViewModel()
    @State private var inputText = ""
    @State private var isKeyboardVisible = false
    @State private var lastScrollPosition: CGFloat = 0
    @State private var scrollPosition: CGFloat = 0
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        iOSChatView(
            viewModel: viewModel,
            inputText: $inputText,
            isKeyboardVisible: $isKeyboardVisible,
            lastScrollPosition: $lastScrollPosition,
            scrollPosition: $scrollPosition,
            isInputFocused: _isInputFocused
        )
    }
}

#Preview("iOS Chat View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, StoredChatMessage.self, configurations: config)
    
    return NavigationView {
        MockiOSChatView()
    }
    .modelContainer(container)
} 