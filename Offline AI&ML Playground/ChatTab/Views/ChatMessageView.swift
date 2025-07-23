//
//  ChatMessageView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Chat Message View
struct ChatMessageView: View {
    let message: ChatMessage
    
    // Pre-computed properties for better performance
    private var isUserMessage: Bool { message.role == .user }
    private var messageAlignment: Alignment { isUserMessage ? .trailing : .leading }
    private var backgroundColor: Color { 
        isUserMessage ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUserMessage {
                Spacer(minLength: 60)
                messageContent
            } else {
                messageContent
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    private var messageContent: some View {
        VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 6) {
            // Optimized text rendering with TextEditor-like behavior for long content
            Text(message.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled) // Allow text selection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(backgroundColor)
                        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                )
                .frame(maxWidth: .infinity, alignment: messageAlignment)
            
            // Metadata row with better spacing
            HStack(spacing: 8) {
                if message.role == .assistant, let modelUsed = message.modelUsed {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text(modelUsed)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, isUserMessage ? 16 : 0)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 8) {
        ChatMessageView(message: ChatMessage(
            content: "Hello, how are you?",
            role: .user,
            timestamp: Date(),
            modelUsed: nil
        ))
        
        ChatMessageView(message: ChatMessage(
            content: "I'm doing well, thank you for asking! How can I help you today?",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "Llama 3.2 3B"
        ))
        
        ChatMessageView(message: ChatMessage(
            content: "Can you help me with a coding problem?",
            role: .user,
            timestamp: Date(),
            modelUsed: nil
        ))
        
        ChatMessageView(message: ChatMessage(
            content: "💻 As a code-focused model, I can help you with your coding problem. Here's my analysis:\n\n```swift\n// Swift example\nfunc solution() {\n    // Your implementation\n}\n```",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "CodeLlama 7B"
        ))
    }
    .padding()
} 