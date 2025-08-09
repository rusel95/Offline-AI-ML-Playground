//
//  StreamingResponseTests.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import XCTest
@testable import Offline_AI_ML_Playground

final class StreamingResponseTests: XCTestCase {
    
    // MARK: - StreamingResponse Tests
    
    func testStreamingResponseInitialization() {
        let metrics = TokenMetrics()
        let response = StreamingResponse(text: "Hello", metrics: metrics)
        
        XCTAssertEqual(response.text, "Hello")
        XCTAssertEqual(response.metrics.totalTokens, 0)
    }
    
    func testStreamingResponseWithMetrics() {
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 5, currentTime: Date())
        
        let response = StreamingResponse(text: "Hello world", metrics: metrics)
        
        XCTAssertEqual(response.text, "Hello world")
        XCTAssertEqual(response.metrics.totalTokens, 5)
        XCTAssertTrue(response.metrics.isGenerating)
    }
    
    // MARK: - Streaming Simulation Tests
    
    func testStreamingSequence() async {
        // Simulate a streaming response sequence
        let streamingResponses = createMockStreamingSequence()
        
        var fullText = ""
        var finalMetrics: TokenMetrics?
        
        for response in streamingResponses {
            fullText += response.text
            finalMetrics = response.metrics
        }
        
        XCTAssertEqual(fullText, "Hello, how can I help you today?")
        XCTAssertNotNil(finalMetrics)
        XCTAssertEqual(finalMetrics?.totalTokens, 8)
        XCTAssertFalse(finalMetrics?.isGenerating ?? true)
    }
    
    func testEmptyTextWithMetricsUpdate() {
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 10, currentTime: Date())
        metrics.finalize()
        
        // Empty text response used for final metrics update
        let response = StreamingResponse(text: "", metrics: metrics)
        
        XCTAssertEqual(response.text, "")
        XCTAssertEqual(response.metrics.totalTokens, 10)
        XCTAssertFalse(response.metrics.isGenerating)
    }
    
    // MARK: - Integration with ChatMessage Tests
    
    func testChatMessageWithTokenMetrics() {
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 42, currentTime: Date())
        metrics.averageTokensPerSecond = 15.5
        metrics.totalGenerationTime = 2.7
        metrics.finalize()
        
        let message = ChatMessage(
            content: "This is a test response",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "TestModel",
            tokenMetrics: metrics
        )
        
        XCTAssertNotNil(message.tokenMetrics)
        XCTAssertEqual(message.tokenMetrics?.totalTokens, 42)
        XCTAssertEqual(message.tokenMetrics?.averageTokensPerSecond, 15.5)
        XCTAssertEqual(message.tokenMetrics?.totalGenerationTime, 2.7)
    }
    
    func testChatMessageMetricsDisplay() {
        var metrics = TokenMetrics()
        metrics.totalTokens = 127
        metrics.averageTokensPerSecond = 14.3
        metrics.totalGenerationTime = 8.9
        
        let message = ChatMessage(
            content: "Test",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "TestModel",
            tokenMetrics: metrics
        )
        
        let displayString = message.tokenMetrics?.displayString ?? ""
        XCTAssertTrue(displayString.contains("127 tokens"))
        XCTAssertTrue(displayString.contains("14.3 tok/s"))
        XCTAssertTrue(displayString.contains("8.9s"))
    }
    
    // MARK: - Performance Characteristics Tests
    
    func testTokenGenerationRateVariation() {
        var responses: [StreamingResponse] = []
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Simulate variable generation rate
        let tokenCounts = [1, 3, 7, 12, 18, 25, 30, 35, 40, 42]
        let timings = [0.1, 0.2, 0.4, 0.7, 1.0, 1.4, 1.8, 2.2, 2.6, 3.0]
        
        for (index, tokenCount) in tokenCounts.enumerated() {
            let time = startTime.addingTimeInterval(timings[index])
            metrics.update(tokenCount: tokenCount, currentTime: time)
            
            let response = StreamingResponse(
                text: "chunk\(index) ",
                metrics: metrics
            )
            responses.append(response)
        }
        
        // Check final metrics
        let finalResponse = responses.last!
        XCTAssertEqual(finalResponse.metrics.totalTokens, 42)
        XCTAssertEqual(finalResponse.metrics.totalGenerationTime, 3.0, accuracy: 0.1)
        XCTAssertEqual(finalResponse.metrics.averageTokensPerSecond, 14.0, accuracy: 1.0)
    }
    
    // MARK: - Edge Cases
    
    func testStreamingResponseWithoutTokens() {
        let metrics = TokenMetrics()
        let response = StreamingResponse(text: "Error: No tokens generated", metrics: metrics)
        
        XCTAssertEqual(response.text, "Error: No tokens generated")
        XCTAssertEqual(response.metrics.totalTokens, 0)
        XCTAssertEqual(response.metrics.displayString, "")
    }
    
    func testRapidStreamingUpdates() {
        var metrics = TokenMetrics()
        var responses: [StreamingResponse] = []
        let startTime = Date()
        
        // Simulate very rapid streaming (100 updates in 1 second)
        for i in 1...100 {
            let time = startTime.addingTimeInterval(Double(i) * 0.01)
            metrics.update(tokenCount: i, currentTime: time)
            
            let response = StreamingResponse(
                text: i % 10 == 0 ? "word " : "",
                metrics: metrics
            )
            responses.append(response)
        }
        
        XCTAssertEqual(responses.count, 100)
        XCTAssertEqual(responses.last?.metrics.totalTokens, 100)
        
        // Should have generated 10 "word " chunks
        let textChunks = responses.filter { !$0.text.isEmpty }
        XCTAssertEqual(textChunks.count, 10)
    }
}

// MARK: - Helper Methods

extension StreamingResponseTests {
    
    /// Create a mock streaming sequence for testing
    func createMockStreamingSequence() -> [StreamingResponse] {
        var responses: [StreamingResponse] = []
        var metrics = TokenMetrics()
        let startTime = Date()
        
        let chunks = [
            (text: "Hello", tokens: 1, time: 0.1),
            (text: ", ", tokens: 2, time: 0.2),
            (text: "how ", tokens: 3, time: 0.4),
            (text: "can ", tokens: 4, time: 0.6),
            (text: "I ", tokens: 5, time: 0.8),
            (text: "help ", tokens: 6, time: 1.0),
            (text: "you ", tokens: 7, time: 1.2),
            (text: "today?", tokens: 8, time: 1.4),
            (text: "", tokens: 8, time: 1.4) // Final metrics update
        ]
        
        for chunk in chunks {
            let time = startTime.addingTimeInterval(chunk.time)
            metrics.update(tokenCount: chunk.tokens, currentTime: time)
            
            if chunk.text.isEmpty {
                metrics.finalize()
            }
            
            let response = StreamingResponse(text: chunk.text, metrics: metrics)
            responses.append(response)
        }
        
        return responses
    }
}