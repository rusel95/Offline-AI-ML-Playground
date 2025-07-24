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
    @StateObject var viewModel: ChatHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    let onLoadConversation: (Conversation) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                
                // Conversations list
                if viewModel.filteredConversations.isEmpty {
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
                            viewModel.cleanupOldConversations(keepLast: 50)
                        } label: {
                            Label("Clean Old Chats", systemImage: "trash.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadConversations()
        }
        .alert("Delete Conversation", isPresented: $viewModel.showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.confirmDelete()
            }
        } message: {
            Text("This conversation will be permanently deleted.")
        }
        .alert("Edit Title", isPresented: .constant(viewModel.editingConversation != nil)) {
            TextField("Conversation Title", text: $viewModel.newTitle)
            Button("Cancel", role: .cancel) {
                viewModel.cancelEdit()
            }
            Button("Save") {
                viewModel.saveEditedTitle()
            }
        } message: {
            Text("Enter a new title for this conversation.")
        }
        .alert("Old chats cleaned! Only the 50 most recent conversations are kept.", isPresented: $viewModel.showCleanupConfirmation) {
            Button("OK", role: .cancel) { }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search conversations...", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !viewModel.searchText.isEmpty {
                Button("Clear") {
                    viewModel.searchText = ""
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
            
            Text(viewModel.searchText.isEmpty ? "No Conversations Yet" : "No Results Found")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(viewModel.searchText.isEmpty ? 
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
            ForEach(viewModel.filteredConversations, id: \.id) { conversation in
                ConversationRowView(
                    conversation: conversation,
                    onTap: {
                        onLoadConversation(conversation)
                        dismiss()
                    },
                    onEdit: {
                        viewModel.prepareToEdit(conversation)
                    },
                    onDelete: {
                        viewModel.prepareToDelete(conversation)
                    }
                )
            }
        }
        .listStyle(PlainListStyle())
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
