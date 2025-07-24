//
//  ChatHistoryViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import SwiftData
import Combine

@MainActor
class ChatHistoryViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var conversations: [Conversation] = []
    @Published var searchText = ""
    @Published var showingDeleteAlert = false
    @Published var conversationToDelete: Conversation?
    @Published var editingConversation: Conversation?
    @Published var newTitle = ""
    @Published var showCleanupConfirmation = false
    
    // MARK: - Dependencies
    private let historyManager: ChatHistoryManager
    
    // MARK: - Computed Properties
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText) ||
                (conversation.messages.contains { message in
                    message.content.localizedCaseInsensitiveContains(searchText)
                })
            }
        }
    }
    
    var hasConversations: Bool {
        !conversations.isEmpty
    }
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.historyManager = ChatHistoryManager(modelContext: modelContext)
        loadConversations()
    }
    
    // MARK: - Public Methods
    func loadConversations() {
        conversations = historyManager.getAllConversations()
    }
    
    func deleteConversation(_ conversation: Conversation) {
        historyManager.deleteConversation(conversation)
        loadConversations()
    }
    
    func updateConversationTitle(_ conversation: Conversation, title: String) {
        historyManager.updateConversationTitle(conversation, title: title)
        loadConversations()
    }
    
    func cleanupOldConversations(keepLast: Int = 50) {
        historyManager.cleanupOldConversations(keepLast: keepLast)
        loadConversations()
        showCleanupConfirmation = true
    }
    
    func prepareToDelete(_ conversation: Conversation) {
        conversationToDelete = conversation
        showingDeleteAlert = true
    }
    
    func prepareToEdit(_ conversation: Conversation) {
        editingConversation = conversation
        newTitle = conversation.title
    }
    
    func confirmDelete() {
        if let conversation = conversationToDelete {
            deleteConversation(conversation)
        }
        conversationToDelete = nil
    }
    
    func saveEditedTitle() {
        if let conversation = editingConversation {
            updateConversationTitle(conversation, title: newTitle)
        }
        editingConversation = nil
        newTitle = ""
    }
    
    func cancelEdit() {
        editingConversation = nil
        newTitle = ""
    }
}