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
    @Published var showingSessionPicker = false
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
                ToolbarItem(placement: .automatic) {
                    Button {
                        viewModel.showingSessionPicker.toggle()
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                
                ToolbarItem(placement: .automatic) {
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

// MARK: - Model Selection Header

struct ModelSelectionHeader: View {
    @ObservedObject var viewModel: SimpleChatViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Model info
            HStack(spacing: 8) {
                // Model type icon
                if let model = viewModel.selectedModel {
                    ZStack {
                        Circle()
                            .fill(model.type.color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: model.type.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(model.type.color)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Active Model")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.modelDisplayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Model switch button
            Button {
                viewModel.showingModelPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("Switch")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
            .disabled(viewModel.availableModels.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Model Picker View

struct ModelPickerView: View {
    @ObservedObject var viewModel: SimpleChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.availableModels.isEmpty {
                    // No models available state
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Models Downloaded")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Download models from the Download tab to start chatting")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Go to Downloads")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Models list
                    List {
                        ForEach(viewModel.availableModels, id: \.id) { model in
                            ModelPickerRow(
                                model: model,
                                isSelected: viewModel.selectedModel?.id == model.id,
                                onSelect: {
                                    viewModel.selectModel(model)
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Model Picker Row

struct ModelPickerRow: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Model icon
                ZStack {
                    Circle()
                        .fill(model.type.color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: model.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(model.type.color)
                }
                
                // Model info
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(model.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray, in: Capsule())
                        
                        Text(model.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(model.type.color, in: Capsule())
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

struct ChatInputView: View {
    @Binding var text: String
    let canSend: Bool
    let isGenerating: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .disabled(isGenerating)
            
            Button(action: onSend) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct EmptyStateView: View {
    @ObservedObject var viewModel: SimpleChatViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Model status icon
            if viewModel.selectedModel != nil {
                Image(systemName: "message")
                    .font(.system(size: 60))
                    .foregroundColor(.blue.opacity(0.3))
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                if viewModel.selectedModel != nil {
                    Text("Start a conversation")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Using \(viewModel.modelDisplayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No Model Selected")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Download and select a model to start chatting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        viewModel.showingModelPicker = true
                    } label: {
                        Text("Select Model")
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ChatMessageView: View {
    let message: SimpleChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: message.isUser ? "person.circle.fill" : "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(message.isUser ? .blue : .green)
                        
                        Text(message.isUser ? "You" : "AI")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(message.isUser ? .blue : .green)
                    }
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        message.isUser
                            ? Color.blue.opacity(0.1)
                            : Color.gray.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct TypingIndicatorView: View {
    let modelName: String
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(modelName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.secondary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animating ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animating
                            )
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Color.gray.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    ChatView()
} 