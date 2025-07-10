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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text(modelName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(.secondary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(animating ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animating
                            )
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    Color.gray.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        TypingIndicatorView(modelName: "Llama 3.2 3B")
        TypingIndicatorView(modelName: "GPT-4")
        TypingIndicatorView(modelName: "Claude")
    }
    .padding()
} 