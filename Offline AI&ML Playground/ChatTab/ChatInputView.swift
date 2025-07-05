//
//  ChatInputView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Chat Input View
struct ChatInputView: View {
    @Binding var text: String
    let canSend: Bool
    let isGenerating: Bool
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .disabled(isGenerating)
            
            Button(action: onSend) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(canSend ? .blue : .gray)
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview
#Preview {
    VStack {
        ChatInputView(
            text: .constant("Hello world"),
            canSend: true,
            isGenerating: false,
            onSend: {}
        )
        
        ChatInputView(
            text: .constant(""),
            canSend: false,
            isGenerating: false,
            onSend: {}
        )
        
        ChatInputView(
            text: .constant("Generating..."),
            canSend: true,
            isGenerating: true,
            onSend: {}
        )
    }
    .padding()
} 