//
//  SimpleChatView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - Simple Chat View
/// Main entry point for the chat interface
/// Wraps the iOS chat view with state management
struct SimpleChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = ChatViewModel()
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

#Preview("Simple Chat View") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Conversation.self, StoredChatMessage.self, configurations: config)
    
    return NavigationView {
        SimpleChatView()
    }
    .modelContainer(container)
} 