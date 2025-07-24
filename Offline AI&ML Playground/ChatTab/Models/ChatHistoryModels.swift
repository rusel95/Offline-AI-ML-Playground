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
        ChatMessage(
            id: self.id,
            content: self.content,
            role: ChatMessage.MessageRole(rawValue: self.role) ?? .user,
            timestamp: self.timestamp,
            modelUsed: self.modelUsed
        )
    }
}

// MARK: - Chat History Manager
@MainActor
class ChatHistoryManager: ObservableObject {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Conversation Management
    
    /// Create a new conversation
    func createConversation(title: String? = nil, modelUsed: String? = nil) -> Conversation {
        let conversation = Conversation(
            title: title ?? "New Conversation",
            modelUsed: modelUsed
        )
        modelContext.insert(conversation)
        saveContext()
        return conversation
    }
    
    /// Save current chat messages to a conversation
    func saveConversation(_ messages: [ChatMessage], title: String? = nil, existingConversation: Conversation? = nil) -> Conversation {
        let conversation = existingConversation ?? createConversation(title: title)
        
        // Clear existing messages if updating
        if let existing = existingConversation {
            existing.messages.removeAll()
        }
        
        // Add all messages
        for message in messages {
            let storedMessage = StoredChatMessage(from: message)
            storedMessage.conversation = conversation
            conversation.messages.append(storedMessage)
            modelContext.insert(storedMessage)
        }
        
        // Generate title if not provided
        if title == nil {
            conversation.generateTitle()
        }
        
        conversation.updatedAt = Date()
        saveContext()
        return conversation
    }
    
    /// Load conversation messages
    func loadConversation(_ conversation: Conversation) -> [ChatMessage] {
        return conversation.messages
            .sorted(by: { $0.timestamp < $1.timestamp })
            .map { $0.toChatMessage }
    }
    
    /// Get all conversations sorted by last activity
    func getAllConversations() -> [Conversation] {
        let descriptor = FetchDescriptor<Conversation>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching conversations: \(error)")
            return []
        }
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) {
        modelContext.delete(conversation)
        saveContext()
    }
    
    /// Update conversation title
    func updateConversationTitle(_ conversation: Conversation, title: String) {
        conversation.title = title
        conversation.updatedAt = Date()
        saveContext()
    }
    
    // MARK: - Search
    
    /// Search conversations by title or content
    func searchConversations(query: String) -> [Conversation] {
        let allConversations = getAllConversations()
        
        if query.isEmpty {
            return allConversations
        }
        
        return allConversations.filter { conversation in
            // Search in title
            if conversation.title.localizedCaseInsensitiveContains(query) {
                return true
            }
            
            // Search in message content
            return conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    // MARK: - Cleanup
    
    /// Delete old conversations (keep last N)
    func cleanupOldConversations(keepLast: Int = 100) {
        let conversations = getAllConversations()
        let toDelete = conversations.dropFirst(keepLast)
        
        for conversation in toDelete {
            modelContext.delete(conversation)
        }
        
        if !toDelete.isEmpty {
            saveContext()
        }
    }
    
    /// Delete all conversations and chat history
    func deleteAllConversations() {
        let conversations = getAllConversations()
        
        for conversation in conversations {
            modelContext.delete(conversation)
        }
        
        saveContext()
        print("📚 Deleted all chat history: \(conversations.count) conversations removed")
    }
    
    // MARK: - Private Methods
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
} 