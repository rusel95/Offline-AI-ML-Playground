//
//  ChatFeature.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

// Import shared types from other modules
// Note: In a real project, these would be imported as modules
// For now, we'll assume these types are available globally

// MARK: - Chat State
struct ChatState: Equatable {
    var currentSession: ChatSession = ChatSession()
    var sessions: [ChatSession] = []
    var messageInput: String = ""
    var isGenerating: Bool = false
    var loadedModel: AIModel?
    var generationError: String?
    var showingSessionPicker: Bool = false
    var generationParameters: GenerationParameters = .default
    
    var canSendMessage: Bool {
        !messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isGenerating &&
        loadedModel != nil
    }
    
    var modelDisplayName: String {
        loadedModel?.displayName ?? "No model loaded"
    }
    
    var hasMessages: Bool {
        !currentSession.messages.isEmpty
    }
}

// MARK: - Chat Actions
enum ChatAction: Equatable {
    case viewAppeared
    case sendMessage
    case messageInputChanged(String)
    case newSession
    case selectSession(ChatSession)
    case deleteSession(ChatSession)
    case clearConversation
    case retryLastMessage
    case cancelGeneration
    case toggleSessionPicker
    case updateGenerationParameters(GenerationParameters)
    
    // Internal actions
    case loadSessions
    case sessionsLoaded([ChatSession])
    case messageGenerated(String)
    case generationCompleted
    case generationFailed(ChatError)
    case sessionSaved(ChatSession)
}

// MARK: - Chat Reducer
@MainActor
class ChatReducer: ObservableObject {
    @Published private(set) var state = ChatState()
    
    func send(_ action: ChatAction) {
        Task {
            await reduce(action)
        }
    }
    
    private func reduce(_ action: ChatAction) async {
        switch action {
        case .viewAppeared:
            await send(.loadSessions)
            
        case .loadSessions:
            // TODO: Load sessions from persistence
            let sessions: [ChatSession] = []
            await send(.sessionsLoaded(sessions))
            
        case let .sessionsLoaded(sessions):
            state.sessions = sessions
            // Load most recent session if available
            if let mostRecent = sessions.max(by: { $0.updatedAt < $1.updatedAt }) {
                state.currentSession = mostRecent
            }
            
        case .sendMessage:
            let messageContent = state.messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !messageContent.isEmpty, let model = state.loadedModel else {
                return
            }
            
            // Create user message
            let userMessage = ChatMessage(
                id: UUID(),
                content: messageContent,
                role: .user,
                timestamp: Date(),
                modelId: model.id
            )
            
            // Update state
            state.currentSession.addMessage(userMessage)
            state.messageInput = ""
            state.isGenerating = true
            state.generationError = nil
            
            // TODO: Generate response using AI service
            // For now, simulate a response
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                Task {
                    await self.send(.messageGenerated("This is a simulated response. Integrate with actual AI service."))
                }
            }
            
        case let .messageInputChanged(input):
            state.messageInput = input
            
        case let .messageGenerated(content):
            guard let model = state.loadedModel else {
                return
            }
            
            let assistantMessage = ChatMessage(
                id: UUID(),
                content: content,
                role: .assistant,
                timestamp: Date(),
                modelId: model.id
            )
            
            state.currentSession.addMessage(assistantMessage)
            let session = state.currentSession
            await send(.generationCompleted)
            
            // TODO: Save session in background
            await send(.sessionSaved(session))
            
        case .generationCompleted:
            state.isGenerating = false
            
        case let .generationFailed(error):
            state.isGenerating = false
            state.generationError = error.localizedDescription
            
        case .newSession:
            // Save current session if it has messages
            let currentSession = state.currentSession
            
            // Create new session
            state.currentSession = ChatSession(
                id: UUID(),
                modelId: state.loadedModel?.id
            )
            state.generationError = nil
            
            if currentSession.hasMessages {
                // TODO: Save session
                await send(.sessionSaved(currentSession))
            }
            await send(.loadSessions)
            
        case let .selectSession(session):
            state.currentSession = session
            state.showingSessionPicker = false
            state.generationError = nil
            
        case let .deleteSession(session):
            // TODO: Delete session from persistence
            await send(.loadSessions)
            
        case .clearConversation:
            state.currentSession = ChatSession(
                id: UUID(),
                modelId: state.loadedModel?.id
            )
            state.generationError = nil
            
        case .retryLastMessage:
            // Remove last assistant message and regenerate
            guard let model = state.loadedModel,
                  let lastMessage = state.currentSession.messages.last,
                  lastMessage.role == .assistant else {
                return
            }
            
            state.currentSession.removeLastMessage()
            state.isGenerating = true
            state.generationError = nil
            
            // TODO: Regenerate response
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                Task {
                    await self.send(.messageGenerated("This is a simulated retry response."))
                }
            }
            
        case .cancelGeneration:
            state.isGenerating = false
            
        case .toggleSessionPicker:
            state.showingSessionPicker.toggle()
            
        case let .updateGenerationParameters(parameters):
            state.generationParameters = parameters
            
        case .sessionSaved:
            break // No state changes needed
        }
    }
}

// Note: ChatSession, GenerationParameters, ChatGenerationRequest, and ChatError 
// are defined in Models/ChatMessage.swift and will be available globally in the Xcode project.
// 
// Additional helper extension for ChatSession
extension ChatSession {
    mutating func removeLastMessage() {
        if !messages.isEmpty {
            messages.removeLast()
            updatedAt = Date()
        }
    }
} 