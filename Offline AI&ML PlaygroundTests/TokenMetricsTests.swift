//
//  TokenMetricsTests.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import XCTest
@testable import Offline_AI_ML_Playground

final class TokenMetricsTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testTokenMetricsInitialization() {
        let metrics = TokenMetrics()
        
        XCTAssertEqual(metrics.totalTokens, 0)
        XCTAssertEqual(metrics.currentTokensPerSecond, 0.0)
        XCTAssertEqual(metrics.averageTokensPerSecond, 0.0)
        XCTAssertNil(metrics.timeToFirstToken)
        XCTAssertEqual(metrics.totalGenerationTime, 0.0)
        XCTAssertFalse(metrics.isGenerating)
        XCTAssertNil(metrics.generationStartTime)
        XCTAssertNil(metrics.firstTokenTime)
        XCTAssertNil(metrics.lastUpdateTime)
    }
    
    // MARK: - Update Tests
    
    func testFirstTokenUpdate() {
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Simulate first token after 0.5 seconds
        let firstTokenTime = startTime.addingTimeInterval(0.5)
        metrics.update(tokenCount: 1, currentTime: firstTokenTime)
        
        XCTAssertEqual(metrics.totalTokens, 1)
        XCTAssertTrue(metrics.isGenerating)
        XCTAssertNotNil(metrics.generationStartTime)
        XCTAssertNotNil(metrics.firstTokenTime)
        XCTAssertNotNil(metrics.timeToFirstToken)
        
        // Time to first token should be approximately 0.5 seconds
        if let ttft = metrics.timeToFirstToken {
            XCTAssertEqual(ttft, 0.5, accuracy: 0.1)
        }
    }
    
    func testMultipleTokenUpdates() {
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Simulate token generation over time
        metrics.update(tokenCount: 1, currentTime: startTime.addingTimeInterval(0.1))
        metrics.update(tokenCount: 5, currentTime: startTime.addingTimeInterval(0.5))
        metrics.update(tokenCount: 10, currentTime: startTime.addingTimeInterval(1.0))
        
        XCTAssertEqual(metrics.totalTokens, 10)
        XCTAssertTrue(metrics.isGenerating)
        XCTAssertGreaterThan(metrics.currentTokensPerSecond, 0)
        XCTAssertGreaterThan(metrics.averageTokensPerSecond, 0)
        
        // Average should be approximately 10 tokens/second
        XCTAssertEqual(metrics.averageTokensPerSecond, 10.0, accuracy: 1.0)
    }
    
    func testTokenRateCalculation() {
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Generate tokens at a steady rate of 20 tokens/second
        for i in 1...20 {
            let time = startTime.addingTimeInterval(Double(i) * 0.05) // 50ms intervals
            metrics.update(tokenCount: i, currentTime: time)
        }
        
        // After 1 second, we should have 20 tokens
        XCTAssertEqual(metrics.totalTokens, 20)
        XCTAssertEqual(metrics.totalGenerationTime, 1.0, accuracy: 0.1)
        XCTAssertEqual(metrics.averageTokensPerSecond, 20.0, accuracy: 2.0)
    }
    
    // MARK: - Finalization Tests
    
    func testMetricsFinalization() {
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Generate some tokens
        metrics.update(tokenCount: 50, currentTime: startTime.addingTimeInterval(2.5))
        
        // Finalize
        metrics.finalize()
        
        XCTAssertFalse(metrics.isGenerating)
        XCTAssertEqual(metrics.totalTokens, 50)
        XCTAssertGreaterThan(metrics.totalGenerationTime, 0)
        XCTAssertGreaterThan(metrics.averageTokensPerSecond, 0)
        
        // Average should be approximately 20 tokens/second (50 tokens in 2.5 seconds)
        XCTAssertEqual(metrics.averageTokensPerSecond, 20.0, accuracy: 1.0)
    }
    
    // MARK: - Display String Tests
    
    func testDisplayStringEmpty() {
        let metrics = TokenMetrics()
        XCTAssertEqual(metrics.displayString, "")
    }
    
    func testDisplayStringWhileGenerating() {
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 42, currentTime: Date())
        metrics.currentTokensPerSecond = 15.7
        
        let display = metrics.displayString
        XCTAssertTrue(display.contains("42 tokens"))
        XCTAssertTrue(display.contains("15.7 tok/s"))
    }
    
    func testDisplayStringCompleted() {
        var metrics = TokenMetrics()
        let startTime = Date()
        
        metrics.update(tokenCount: 127, currentTime: startTime)
        metrics.totalGenerationTime = 8.9
        metrics.averageTokensPerSecond = 14.3
        metrics.finalize()
        
        let display = metrics.displayString
        XCTAssertTrue(display.contains("127 tokens"))
        XCTAssertTrue(display.contains("14.3 tok/s"))
        XCTAssertTrue(display.contains("8.9s"))
    }
    
    func testDisplayStringSingularToken() {
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 1, currentTime: Date())
        
        let display = metrics.displayString
        XCTAssertTrue(display.contains("1 token")) // Singular, not "tokens"
        XCTAssertFalse(display.contains("1 tokens"))
    }
    
    // MARK: - Edge Cases
    
    func testZeroTokenGeneration() {
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 0, currentTime: Date())
        
        XCTAssertEqual(metrics.totalTokens, 0)
        XCTAssertNil(metrics.timeToFirstToken) // No first token time for zero tokens
    }
    
    func testRapidUpdates() {
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Simulate very rapid updates (every 1ms)
        for i in 1...100 {
            let time = startTime.addingTimeInterval(Double(i) * 0.001)
            metrics.update(tokenCount: i, currentTime: time)
        }
        
        XCTAssertEqual(metrics.totalTokens, 100)
        // Should handle rapid updates without crashing
        XCTAssertGreaterThan(metrics.currentTokensPerSecond, 0)
    }
    
    // MARK: - Codable Tests
    
    func testTokenMetricsCodable() throws {
        var originalMetrics = TokenMetrics()
        originalMetrics.update(tokenCount: 50, currentTime: Date())
        originalMetrics.averageTokensPerSecond = 25.5
        originalMetrics.totalGenerationTime = 2.0
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMetrics)
        
        // Decode
        let decoder = JSONDecoder()
        let decodedMetrics = try decoder.decode(TokenMetrics.self, from: data)
        
        XCTAssertEqual(originalMetrics.totalTokens, decodedMetrics.totalTokens)
        XCTAssertEqual(originalMetrics.averageTokensPerSecond, decodedMetrics.averageTokensPerSecond)
        XCTAssertEqual(originalMetrics.totalGenerationTime, decodedMetrics.totalGenerationTime)
    }
    
    // MARK: - Performance Tests
    
    func testUpdatePerformance() {
        var metrics = TokenMetrics()
        
        measure {
            // Measure the performance of 1000 updates
            let startTime = Date()
            for i in 1...1000 {
                let time = startTime.addingTimeInterval(Double(i) * 0.001)
                metrics.update(tokenCount: i, currentTime: time)
            }
        }
    }
}

// MARK: - Helper Extensions

extension TokenMetricsTests {
    /// Create a metrics instance with preset values for testing
    func createTestMetrics(tokens: Int, duration: TimeInterval, tokensPerSecond: Double) -> TokenMetrics {
        var metrics = TokenMetrics()
        metrics.totalTokens = tokens
        metrics.totalGenerationTime = duration
        metrics.averageTokensPerSecond = tokensPerSecond
        metrics.isGenerating = false
        return metrics
    }
}