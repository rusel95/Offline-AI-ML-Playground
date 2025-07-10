//
//  ChatHistoryServiceProtocol.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import SwiftData

// MARK: - Chat History Service Protocol
/// Protocol defining the interface for chat history management
/// This protocol abstracts the conversation saving and loading functionality
protocol ChatHistoryServiceProtocol {
    /// Sets up the history manager with a SwiftData model context
    /// - Parameter modelContext: The SwiftData model context for persistence
    func setupHistoryManager(_ modelContext: ModelContext)
    
    /// Saves a conversation to persistent storage
    /// - Parameters:
    ///   - messages: Array of chat messages to save
    ///   - title: Optional title for the conversation
    ///   - existingConversation: Optional existing conversation to update
    /// - Returns: The saved conversation object
    func saveConversation(_ messages: [ChatMessage], title: String?, existingConversation: Conversation?) -> Conversation?
    
    /// Loads a conversation from persistent storage
    /// - Parameter conversation: The conversation to load
    /// - Returns: Array of chat messages from the conversation
    func loadConversation(_ conversation: Conversation) async -> [ChatMessage]
}

// MARK: - Preview Helper
struct MockChatHistoryService: ChatHistoryServiceProtocol {
    func setupHistoryManager(_ modelContext: ModelContext) {
        // Mock implementation
    }
    
    func saveConversation(_ messages: [ChatMessage], title: String?, existingConversation: Conversation?) -> Conversation? {
        // Mock implementation - return nil for preview
        return nil
    }
    
    func loadConversation(_ conversation: Conversation) async -> [ChatMessage] {
        // Mock implementation
        return []
    }
}

#Preview("Chat History Service Protocol") {
    VStack(spacing: 20) {
        Text("Chat History Service Protocol")
            .font(.title)
            .fontWeight(.bold)
        
        Text("This protocol defines the interface for chat history management including:")
            .font(.subheadline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("• setupHistoryManager(_:) - Initialize with SwiftData context")
            Text("• saveConversation(...) - Save conversations to storage")
            Text("• loadConversation(_:) - Load conversations from storage")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
} 