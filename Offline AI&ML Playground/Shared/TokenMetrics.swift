//
//  TokenMetrics.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation

/// Metrics for token generation during AI inference
public struct TokenMetrics: Codable, Equatable {
    /// Total number of tokens generated
    public var totalTokens: Int = 0
    
    /// Current tokens per second rate
    public var currentTokensPerSecond: Double = 0.0
    
    /// Average tokens per second over the entire generation
    public var averageTokensPerSecond: Double = 0.0
    
    /// Time to first token in seconds
    public var timeToFirstToken: TimeInterval?
    
    /// Total generation time in seconds
    public var totalGenerationTime: TimeInterval = 0.0
    
    /// Whether generation is currently in progress
    public var isGenerating: Bool = false
    
    /// Timestamp when generation started
    public var generationStartTime: Date?
    
    /// Timestamp when first token was received
    public var firstTokenTime: Date?
    
    /// Timestamp of last update
    public var lastUpdateTime: Date?
    
    /// Initialize empty metrics
    public init() {}
    
    /// Format metrics for display
    public var displayString: String {
        if totalTokens == 0 {
            return ""
        }
        
        var parts: [String] = []
        
        // Token count
        parts.append("\(totalTokens) \(totalTokens == 1 ? "token" : "tokens")")
        
        // Tokens per second (show current while generating, average when done)
        if isGenerating && currentTokensPerSecond > 0 {
            parts.append(String(format: "%.1f tok/s", currentTokensPerSecond))
        } else if averageTokensPerSecond > 0 {
            parts.append(String(format: "%.1f tok/s", averageTokensPerSecond))
        }
        
        // Total time
        if totalGenerationTime > 0 {
            parts.append(String(format: "%.1fs", totalGenerationTime))
        }
        
        return parts.joined(separator: " • ")
    }
    
    /// Update metrics with new token count
    public mutating func update(tokenCount: Int, currentTime: Date = Date()) {
        // Update total tokens
        totalTokens = tokenCount
        
        // Track generation start time
        if generationStartTime == nil {
            generationStartTime = currentTime
            isGenerating = true
        }
        
        // Track time to first token
        if tokenCount > 0 && firstTokenTime == nil {
            firstTokenTime = currentTime
            if let startTime = generationStartTime {
                timeToFirstToken = currentTime.timeIntervalSince(startTime)
            }
        }
        
        // Calculate current tokens per second
        if let lastTime = lastUpdateTime, tokenCount > 0 {
            let timeDelta = currentTime.timeIntervalSince(lastTime)
            if timeDelta > 0 {
                // Simple smoothing to avoid jumpy values
                let instantRate = 1.0 / timeDelta
                currentTokensPerSecond = currentTokensPerSecond > 0 
                    ? (currentTokensPerSecond * 0.7 + instantRate * 0.3)
                    : instantRate
            }
        }
        
        // Update total generation time
        if let startTime = generationStartTime {
            totalGenerationTime = currentTime.timeIntervalSince(startTime)
            
            // Calculate average tokens per second
            if totalGenerationTime > 0 && totalTokens > 0 {
                averageTokensPerSecond = Double(totalTokens) / totalGenerationTime
            }
        }
        
        lastUpdateTime = currentTime
    }
    
    /// Mark generation as completed
    public mutating func finalize() {
        isGenerating = false
        // Final calculation of average
        if let startTime = generationStartTime {
            totalGenerationTime = Date().timeIntervalSince(startTime)
            if totalGenerationTime > 0 && totalTokens > 0 {
                averageTokensPerSecond = Double(totalTokens) / totalGenerationTime
            }
        }
    }
}

/// Response structure for streaming text generation with metrics
public struct StreamingResponse {
    /// The generated text chunk
    public let text: String
    
    /// Performance metrics for this response
    public let metrics: TokenMetrics
    
    /// Whether this is the final response
    public let isComplete: Bool
    
    public init(text: String, metrics: TokenMetrics, isComplete: Bool = false) {
        self.text = text
        self.metrics = metrics
        self.isComplete = isComplete
    }
}