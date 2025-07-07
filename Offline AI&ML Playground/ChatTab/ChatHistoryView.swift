//
//  ChatHistoryView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

struct ChatHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var historyManager: ChatHistoryManager
    @State private var searchText = ""
    @State private var conversations: [Conversation] = []
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: Conversation?
    @State private var editingConversation: Conversation?
    @State private var newTitle = ""
    
    let onLoadConversation: (Conversation) -> Void
    
    init(modelContext: ModelContext, onLoadConversation: @escaping (Conversation) -> Void) {
        self._historyManager = StateObject(wrappedValue: ChatHistoryManager(modelContext: modelContext))
        self.onLoadConversation = onLoadConversation
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Conversations list
                if filteredConversations.isEmpty {
                    emptyStateView
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Chat History")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            historyManager.cleanupOldConversations(keepLast: 50)
                            loadConversations()
                        } label: {
                            Label("Clean Old Chats", systemImage: "trash.circle")
                        }
                        
                        Button {
                            searchText = ""
                            loadConversations()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadConversations()
        }
        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    historyManager.deleteConversation(conversation)
                    loadConversations()
                }
            }
        } message: {
            Text("This conversation will be permanently deleted.")
        }
        .alert("Edit Title", isPresented: .constant(editingConversation != nil)) {
            TextField("Conversation Title", text: $newTitle)
            Button("Cancel", role: .cancel) {
                editingConversation = nil
                newTitle = ""
            }
            Button("Save") {
                if let conversation = editingConversation {
                    historyManager.updateConversationTitle(conversation, title: newTitle)
                    loadConversations()
                }
                editingConversation = nil
                newTitle = ""
            }
        } message: {
            Text("Enter a new title for this conversation.")
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search conversations...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onChange(of: searchText) { _, _ in
                    filterConversations()
                }
            
            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "message.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "No Conversations Yet" : "No Results Found")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? 
                 "Start a conversation in the chat tab to see it here." :
                 "Try searching with different keywords.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Conversations List
    
    private var conversationsList: some View {
        List {
            ForEach(filteredConversations, id: \.id) { conversation in
                ConversationRowView(
                    conversation: conversation,
                    onTap: {
                        onLoadConversation(conversation)
                        dismiss()
                    },
                    onEdit: {
                        editingConversation = conversation
                        newTitle = conversation.title
                    },
                    onDelete: {
                        conversationToDelete = conversation
                        showingDeleteAlert = true
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return historyManager.searchConversations(query: searchText)
        }
    }
    
    // MARK: - Methods
    
    private func loadConversations() {
        conversations = historyManager.getAllConversations()
    }
    
    private func filterConversations() {
        // Real-time filtering is handled by computed property
    }
}

// MARK: - Conversation Row View

struct ConversationRowView: View {
    let conversation: Conversation
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Conversation icon
                Image(systemName: "message.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                // Conversation details
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let modelUsed = conversation.modelUsed {
                            Text(modelUsed)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Text("\(conversation.messageCount) messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(conversation.lastMessageDate.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action menu
                Menu {
                    Button("Load Conversation") {
                        onTap()
                    }
                    
                    Button("Edit Title") {
                        onEdit()
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, StoredChatMessage.self, configurations: config)
    
    return ChatHistoryView(modelContext: container.mainContext) { conversation in
        print("Loading conversation: \(conversation.title)")
    }
} 