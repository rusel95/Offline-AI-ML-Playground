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
    
    // Throttle focus change callbacks for better performance
    @State private var debounceTimer: Timer?
    
    var body: some View {
        HStack(spacing: 12) {
            // Optimized text field with better performance
            TextField("Type a message...", text: $text, axis: .vertical)
                .textFieldStyle(OptimizedTextFieldStyle())
                .focused($isInputFocused)
                .disabled(isGenerating)
                .lineLimit(1...4) // Reduced max lines for better performance
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .onChange(of: isInputFocused) { _, focused in
                    // Debounce focus changes to reduce UI updates
                    debounceTimer?.invalidate()
                    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                        onFocusChanged(focused)
                    }
                }
            
            // Optimized send button with better animations
            SendButton(
                canSend: canSend,
                isGenerating: isGenerating,
                onSend: {
                    onSend()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isInputFocused = false
                    }
                }
            )
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
    
    // Public methods for focus control
    func focusInput() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isInputFocused = true
        }
    }
    
    func unfocusInput() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isInputFocused = false
        }
    }
}

// MARK: - Optimized Text Field Style
struct OptimizedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .font(.body)
    }
}

// MARK: - Optimized Send Button
struct SendButton: View {
    let canSend: Bool
    let isGenerating: Bool
    let onSend: () -> Void
    
    var body: some View {
        Button(action: onSend) {
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
        }
        .frame(width: 36, height: 36)
        .background(
            Circle()
                .fill(canSend ? Color.accentColor : Color.secondary)
                .scaleEffect(canSend ? 1.0 : 0.8)
        )
        .disabled(!canSend)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
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