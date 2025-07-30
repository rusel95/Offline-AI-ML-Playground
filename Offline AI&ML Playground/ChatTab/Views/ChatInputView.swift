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
    @FocusState var isInputFocused: Bool
    let canSend: Bool
    let isGenerating: Bool
    let onSend: () -> Void
    let onFocusChanged: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Simplified text field for better performance
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemGray6))
                )
                .font(.body)
                .focused($isInputFocused)
                .disabled(isGenerating)
                .lineLimit(1...5)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    onFocusChanged(focused)
                }
            
            // Send button
            Button(action: {
                if canSend {
                    onSend()
                    isInputFocused = false
                }
            }) {
                Group {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(canSend ? Color.accentColor : Color.secondary)
                )
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}


// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ChatInputView(
            text: .constant("Hello world! This is a longer message to test the multi-line behavior."),
            canSend: true,
            isGenerating: false,
            onSend: {},
            onFocusChanged: { _ in }
        )
        
        ChatInputView(
            text: .constant(""),
            canSend: false,
            isGenerating: false,
            onSend: {},
            onFocusChanged: { _ in }
        )
        
        ChatInputView(
            text: .constant("Generating response..."),
            canSend: false,
            isGenerating: true,
            onSend: {},
            onFocusChanged: { _ in }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
} 