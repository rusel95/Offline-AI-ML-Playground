//
//  ChatInputViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

@MainActor
class ChatInputViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messageText = ""
    @Published var isComposing = false
    
    // MARK: - Dependencies
    private let chatViewModel: ChatViewModel
    
    // MARK: - Computed Properties
    var canSendMessage: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !chatViewModel.isGenerating &&
        chatViewModel.selectedModel != nil
    }
    
    var sendButtonOpacity: Double {
        canSendMessage ? 1.0 : 0.5
    }
    
    var placeholderText: String {
        if chatViewModel.selectedModel == nil {
            return "Select a model to start chatting..."
        } else if chatViewModel.isGenerating {
            return "AI is generating response..."
        } else {
            return "Type a message..."
        }
    }
    
    // MARK: - Initialization
    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
    }
    
    // MARK: - Public Methods
    func sendMessage() {
        guard canSendMessage else { return }
        
        let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        isComposing = false
        
        chatViewModel.sendMessage(message)
    }
    
    func handleKeyPress(_ key: String) -> Bool {
        // Handle enter key to send message
        if key == "\n" && !isComposing {
            sendMessage()
            return true
        }
        return false
    }
}