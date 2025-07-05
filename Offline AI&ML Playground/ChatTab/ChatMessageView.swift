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
    let message: SimpleChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: message.isUser ? "person.circle.fill" : "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(message.isUser ? .blue : .green)
                        
                        Text(message.isUser ? "You" : "AI")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(message.isUser ? .blue : .green)
                    }
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        message.isUser
                            ? Color.blue.opacity(0.1)
                            : Color.gray.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        ChatMessageView(
            message: SimpleChatMessage(
                content: "Hello! How can I help you today?",
                isUser: false,
                timestamp: Date()
            )
        )
        
        ChatMessageView(
            message: SimpleChatMessage(
                content: "I'd like to know more about SwiftUI development.",
                isUser: true,
                timestamp: Date()
            )
        )
        
        ChatMessageView(
            message: SimpleChatMessage(
                content: "SwiftUI is Apple's modern UI framework that allows you to build user interfaces across all Apple platforms using declarative syntax. Here are some key concepts:\n\n1. Views are structs that conform to the View protocol\n2. State management using @State, @Binding, etc.\n3. Modifiers for styling and behavior",
                isUser: false,
                timestamp: Date()
            )
        )
    }
    .padding()
} 