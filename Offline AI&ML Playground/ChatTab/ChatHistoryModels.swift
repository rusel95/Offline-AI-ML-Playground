//
//  ChatHistoryModels.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import SwiftData

// MARK: - Conversation Model
@Model
class Conversation {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var modelUsed: String?
    @Relationship(deleteRule: .cascade) var messages: [StoredChatMessage] = []
    
    init(title: String, modelUsed: String? = nil) {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
        self.modelUsed = modelUsed
    }
    
    // Generate a title from the first user message
    func generateTitle() {
        if let firstUserMessage = messages.first(where: { $0.role == "user" }) {
            let words = firstUserMessage.content.components(separatedBy: .whitespacesAndNewlines)
            self.title = words.prefix(6).joined(separator: " ")
            if words.count > 6 {
                self.title += "..."
            }
        } else {
            self.title = "New Conversation"
        }
        self.updatedAt = Date()
    }
    
    var messageCount: Int {
        messages.count
    }
    
    var lastMessageDate: Date {
        messages.last?.timestamp ?? updatedAt
    }
}

// MARK: - Stored Chat Message Model
@Model
class StoredChatMessage {
    var id: UUID
    var content: String
    var role: String
    var timestamp: Date
    var modelUsed: String?
    var conversation: Conversation?
    
    init(content: String, role: String, timestamp: Date = Date(), modelUsed: String? = nil) {
        self.id = UUID()
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.modelUsed = modelUsed
    }
    
    // Convert from ChatMessage
    init(from chatMessage: ChatMessage) {
        self.id = chatMessage.id
        self.content = chatMessage.content
        self.role = chatMessage.role.rawValue
        self.timestamp = chatMessage.timestamp
        self.modelUsed = chatMessage.modelUsed
    }
    
    // Convert to ChatMessage
    var toChatMessage: ChatMessage {
        var chatMessage = ChatMessage(
            content: self.content,
            role: ChatMessage.MessageRole(rawValue: self.role) ?? .user,
            timestamp: self.timestamp,
            modelUsed: self.modelUsed
        )
        // Set the ID to match the stored message
        chatMessage.id = self.id
        return chatMessage
    }
}

// MARK: - Chat History Manager
@MainActor
class ChatHistoryManager: ChatHistoryServiceProtocol, ObservableObject {
    private var modelContext: ModelContext?
    
    func setupHistoryManager(_ modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func saveConversation(_ messages: [ChatMessage], title: String?, existingConversation: Conversation?) -> Conversation? {
        guard let modelContext = modelContext else { return nil }
        
        let conversation: Conversation
        if let existing = existingConversation {
            conversation = existing
            // Clear existing messages
            conversation.messages.removeAll()
        } else {
            conversation = Conversation(title: title ?? generateTitle(from: messages.first?.content ?? ""))
            modelContext.insert(conversation)
        }
        
        // Set conversation properties
        conversation.title = title ?? generateTitle(from: messages.first?.content ?? "")
        conversation.updatedAt = Date()
        conversation.modelUsed = messages.first(where: { $0.role == .assistant })?.modelUsed
        
        // Convert and add messages
        for message in messages {
            let storedMessage = StoredChatMessage(
                content: message.content,
                role: message.role.rawValue,
                timestamp: message.timestamp,
                modelUsed: message.modelUsed
            )
            storedMessage.id = message.id
            storedMessage.conversation = conversation
            
            modelContext.insert(storedMessage)
            conversation.messages.append(storedMessage)
        }
        
        do {
            try modelContext.save()
            return conversation
        } catch {
            print("❌ Failed to save conversation: \(error)")
            return nil
        }
    }
    
    func loadConversation(_ conversation: Conversation) async -> [ChatMessage] {
        return conversation.messages.map { storedMessage in
            ChatMessage(
                content: storedMessage.content,
                role: ChatMessage.MessageRole(rawValue: storedMessage.role) ?? .user,
                timestamp: storedMessage.timestamp,
                modelUsed: storedMessage.modelUsed
            )
        }
    }
    
    private func generateTitle(from firstMessage: String) -> String {
        let words = firstMessage.components(separatedBy: .whitespacesAndNewlines)
        let titleWords = Array(words.prefix(5))
        return titleWords.joined(separator: " ") + (words.count > 5 ? "..." : "")
    }
} 