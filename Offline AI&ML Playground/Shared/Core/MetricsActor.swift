//
//  MetricsActor.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 14.01.2025.
//

import Foundation

/// Actor for thread-safe metrics tracking during text generation
@MainActor
public class TokenMetricsActor {
    private var metrics = TokenMetrics()
    
    public init() {
        // Initialize with current time
        metrics.generationStartTime = Date()
        metrics.isGenerating = true
    }
    
    /// Update metrics with new token count
    public func update(tokenCount: Int, currentTime: Date) {
        metrics.update(tokenCount: tokenCount, currentTime: currentTime)
    }
    
    /// Get current metrics
    public func getMetrics() -> TokenMetrics {
        return metrics
    }
    
    /// Finalize metrics calculation
    public func finalize() {
        metrics.finalize()
    }
}