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
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .focused($isInputFocused)
                .disabled(isGenerating)
                .lineLimit(1...6) // Limit to reasonable height
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    onFocusChanged(focused)
                }
                .onTapGesture {
                    // Focus input when tapped
                    isInputFocused = true
                }
            
            Button(action: {
                onSend()
                // Hide keyboard after sending
                isInputFocused = false
            }) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? Color.accentColor : Color.secondary)
                }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    // Public method to control focus from parent
    func focusInput() {
        isInputFocused = true
    }
    
    func unfocusInput() {
        isInputFocused = false
    }
}

// MARK: - Preview
#Preview {
    VStack {
        ChatInputView(
            text: .constant("Hello world"),
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
            text: .constant("Generating..."),
            canSend: true,
            isGenerating: true,
            onSend: {},
            onFocusChanged: { _ in }
        )
    }
    .padding()
} 