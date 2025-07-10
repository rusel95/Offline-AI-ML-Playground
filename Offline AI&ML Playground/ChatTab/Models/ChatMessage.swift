//
//  ChatMessage.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Chat Message
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let content: String
    let role: MessageRole
    let timestamp: Date
    let modelUsed: String?
    
    enum MessageRole: String, Codable, CaseIterable {
        case user = "user"
        case assistant = "assistant"
        case system = "system"
    }
}

// MARK: - Preview
#Preview("Chat Message") {
    VStack(spacing: 20) {
        Text("User Message")
            .font(.headline)
        Text(ChatMessage(
            content: "Hello, how are you?",
            role: .user,
            timestamp: Date(),
            modelUsed: nil
        ).content)
        
        Text("Assistant Message")
            .font(.headline)
        Text(ChatMessage(
            content: "I'm doing well, thank you for asking! How can I help you today?",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "Llama 2 7B"
        ).content)
        
        Text("System Message")
            .font(.headline)
        Text(ChatMessage(
            content: "You are a helpful AI assistant.",
            role: .system,
            timestamp: Date(),
            modelUsed: nil
        ).content)
    }
    .padding()
} 