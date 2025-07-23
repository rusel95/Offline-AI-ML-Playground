//
//  EmptyStateView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Enhanced Empty State View
struct EmptyStateView: View {
    @ObservedObject var viewModel: SimpleChatViewModel
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Enhanced animated icon
            Group {
                if let model = viewModel.selectedModel {
                    // Model-specific icon with animation
                    VStack(spacing: 16) {
                        Image(systemName: model.displayIcon)
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [model.displayColor, model.displayColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(animateIcon ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true),
                                value: animateIcon
                            )
                        
                        // Model provider badge
                        HStack(spacing: 6) {
                            Image(systemName: model.provider.iconName)
                                .font(.caption)
                            Text(model.provider.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    }
                } else {
                    // No model selected state
                    Image(systemName: "cpu")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateIcon ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true),
                            value: animateIcon
                        )
                }
            }
            
            // Enhanced text content
            VStack(spacing: 12) {
                if let model = viewModel.selectedModel {
                    Text("Ready to Chat")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 6) {
                        Text("Using **\(model.name)**")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Type a message below to start the conversation")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Suggested prompts
                    VStack(spacing: 8) {
                        Text("Try asking:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(getSuggestedPrompts(for: model), id: \.self) { prompt in
                                Text(prompt)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                } else {
                    Text("No Model Selected")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text("Choose a model to start chatting with AI")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Enhanced action buttons
                    VStack(spacing: 12) {
                        Button {
                            HapticFeedback.selectionChanged()
                            viewModel.showingModelPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cpu")
                                Text("Select Model")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                        }
                        
                        Button {
                            viewModel.shouldNavigateToDownloads = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle")
                                Text("Download Models")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .onAppear {
            animateIcon = true
        }
    }
    
    // Helper function for model-specific prompts
    private func getSuggestedPrompts(for model: AIModel) -> [String] {
        switch model.type {
        case .code:
            return ["Write code", "Debug help", "Explain function"]
        case .llama, .mistral, .general:
            return ["Hello!", "Explain AI", "Creative story"]
        case .stable_diffusion:
            return ["Generate image", "Art prompt", "Style guide"]
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        EmptyStateView(viewModel: SimpleChatViewModel())
    }
    .background(Color(.systemGroupedBackground))
} 