//
//  ChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - Main Chat View
/// Main chat interface entry point
/// This file serves as the primary entry point for the chat functionality
struct ChatView: View {
    var body: some View {
        SimpleChatView()
    }
}

#Preview("Chat View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, StoredChatMessage.self, configurations: config)
    
    return NavigationView {
        ChatView()
    }
    .modelContainer(container)
} 
