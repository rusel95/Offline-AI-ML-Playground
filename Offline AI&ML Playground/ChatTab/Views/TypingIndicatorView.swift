//
//  TypingIndicatorView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    let modelName: String
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // Model indicator with better styling
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Text(modelName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                    
                    Text("is thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                
                // Optimized animated dots with better performance
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        DotView(index: index, animating: animating)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.secondary.opacity(0.08))
                        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                )
            }
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation {
                animating = true
            }
        }
        .onDisappear {
            animating = false
        }
    }
}

// MARK: - Optimized Dot View
struct DotView: View {
    let index: Int
    let animating: Bool
    
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        Circle()
            .fill(.secondary)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .onChange(of: animating) { _, newValue in
                if newValue {
                    startAnimation()
                } else {
                    scale = 0.8
                }
            }
    }
    
    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.2)
        ) {
            scale = 1.2
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        TypingIndicatorView(modelName: "Llama 3.2 3B")
        TypingIndicatorView(modelName: "DeepSeek Coder")
        TypingIndicatorView(modelName: "Mistral 7B")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
} 