//
//  ChatServiceProtocol.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation

// MARK: - Chat Service Protocol
/// Protocol defining the interface for AI chat services
/// This protocol abstracts the AI model loading and text generation functionality
protocol ChatServiceProtocol {
    /// Loads an AI model for inference
    /// - Parameter model: The AI model to load
    /// - Throws: Error if model loading fails
    func loadModel(_ model: AIModel) async throws
    
    /// Generates streaming text using the loaded model
    /// - Parameters:
    ///   - prompt: The input text prompt
    ///   - maxTokens: Maximum number of tokens to generate
    ///   - temperature: Controls randomness in generation (0.0 = deterministic, 1.0 = very random)
    /// - Returns: AsyncStream of generated text chunks
    func generateStreamingText(prompt: String, maxTokens: Int, temperature: Double) -> AsyncStream<String>
    
    /// Indicates whether a model is currently loaded and ready for inference
    var isModelLoaded: Bool { get }
}

// MARK: - Preview Helper
struct MockChatService: ChatServiceProtocol {
    var isModelLoaded: Bool = false
    
    func loadModel(_ model: AIModel) async throws {
        // Simulate loading delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        isModelLoaded = true
    }
    
    func generateStreamingText(prompt: String, maxTokens: Int, temperature: Double) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                let response = "This is a mock response to: \(prompt)"
                for char in response {
                    continuation.yield(String(char))
                    try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                }
                continuation.finish()
            }
        }
    }
}

#Preview("Chat Service Protocol") {
    VStack(spacing: 20) {
        Text("Chat Service Protocol")
            .font(.title)
            .fontWeight(.bold)
        
        Text("This protocol defines the interface for AI chat services including:")
            .font(.subheadline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("• loadModel(_:) - Load AI models for inference")
            Text("• generateStreamingText(...) - Generate streaming text")
            Text("• isModelLoaded - Check if model is ready")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
} 