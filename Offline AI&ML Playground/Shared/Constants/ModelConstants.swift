//
//  ModelConstants.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation

enum ModelConstants {
    // Generation parameters
    static let defaultTemperature: Float = 0.7
    static let defaultTopP: Float = 0.9
    static let defaultMaxOutputTokens = 512
    static let minTemperature: Float = 0.0
    static let maxTemperature: Float = 2.0
    
    // Context and token limits
    static let defaultMaxContextTokens = 2048
    static let minContextTokens = 256
    static let responseBufferTokens = 200
    static let tokenEstimateRatio = 4 // Approximate characters per token
    
    // Model size thresholds
    static let largeModelThreshold: Int64 = 5_000_000_000 // 5GB
    static let mediumModelThreshold: Int64 = 1_000_000_000 // 1GB
    
    // Performance settings
    static let memoryCleanupThreshold: Double = 0.8 // 80% memory usage
    static let downloadProgressUpdateInterval: TimeInterval = 0.25
    static let speedTrackerSampleWindow = 10
    
    // UI settings
    static let maxChatHistoryDisplay = 10
    static let messagePreviewLength = 100
    
    // File size formatting
    static let bytesPerKB: Double = 1024
    static let bytesPerMB: Double = 1024 * 1024
    static let bytesPerGB: Double = 1024 * 1024 * 1024
}

enum ModelTags {
    static let vision = "vision"
    static let embedding = "embedding"
    static let language = "language"
    static let chat = "chat"
    static let instruct = "instruct"
    static let code = "code"
}

enum ModelProviders {
    static let meta = "meta-llama"
    static let mistral = "mistralai"
    static let microsoft = "microsoft"
    static let openAI = "openai"
    static let anthropic = "anthropic"
    static let google = "google"
    static let tinyLlama = "TinyLlama"
}