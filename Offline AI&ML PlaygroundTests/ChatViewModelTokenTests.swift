//
//  ChatViewModelTokenTests.swift
//  Offline AI&ML PlaygroundTests
//
//  Created by Assistant on 07.01.2025.
//

import XCTest
import Combine
@testable import Offline_AI_ML_Playground

final class ChatViewModelTokenTests: XCTestCase {
    
    var viewModel: ChatViewModel!
    var mockInferenceManager: MockAIInferenceManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        viewModel = ChatViewModel()
        mockInferenceManager = MockAIInferenceManager()
        cancellables = []
    }
    
    override func tearDown() {
        viewModel = nil
        mockInferenceManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Message Creation Tests
    
    func testAssistantMessageCreatedWithTokenMetrics() {
        // Given
        let userMessage = "Hello, AI!"
        let model = AIModel(
            id: "test-model",
            name: "Test Model",
            size: "1GB",
            downloadUrl: "https://example.com/model",
            localPath: "/path/to/model",
            isDownloaded: true,
            type: .general,
            huggingFaceRepo: "test/model",
            filename: "model.bin",
            sizeInBytes: 1_000_000_000,
            tags: []
        )
        
        // When
        viewModel.sendMessage(userMessage, using: model)
        
        // Then - verify user message is added
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages[0].role, .user)
        XCTAssertEqual(viewModel.messages[0].content, userMessage)
        
        // Wait for assistant message to be created
        let expectation = XCTestExpectation(description: "Assistant message created")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Assistant message should be created with empty metrics
            if self.viewModel.messages.count > 1 {
                let assistantMessage = self.viewModel.messages[1]
                XCTAssertEqual(assistantMessage.role, .assistant)
                XCTAssertNotNil(assistantMessage.tokenMetrics)
                XCTAssertEqual(assistantMessage.tokenMetrics?.totalTokens, 0)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Token Metrics Update Tests
    
    func testTokenMetricsUpdateDuringStreaming() {
        // Given
        let expectation = XCTestExpectation(description: "Token metrics updated")
        var metricsUpdates: [TokenMetrics] = []
        
        // Create a test message
        let message = ChatMessage(
            content: "",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "Test Model",
            tokenMetrics: TokenMetrics()
        )
        viewModel.messages.append(message)
        
        // Observe metrics changes
        viewModel.$messages
            .compactMap { $0.last?.tokenMetrics }
            .sink { metrics in
                metricsUpdates.append(metrics)
                if metrics.totalTokens >= 10 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Simulate streaming updates
        Task {
            for i in 1...10 {
                var updatedMetrics = TokenMetrics()
                updatedMetrics.update(tokenCount: i, currentTime: Date())
                
                await MainActor.run {
                    if !self.viewModel.messages.isEmpty {
                        self.viewModel.messages[0].tokenMetrics = updatedMetrics
                    }
                }
                
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify metrics were updated progressively
        XCTAssertGreaterThan(metricsUpdates.count, 5)
        XCTAssertEqual(metricsUpdates.last?.totalTokens, 10)
    }
    
    // MARK: - Display String Tests
    
    func testTokenMetricsDisplayInMessage() {
        // Given
        var metrics = TokenMetrics()
        metrics.totalTokens = 42
        metrics.averageTokensPerSecond = 15.5
        metrics.totalGenerationTime = 2.7
        
        let message = ChatMessage(
            content: "Test response",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "Test Model",
            tokenMetrics: metrics
        )
        
        // When
        viewModel.messages.append(message)
        
        // Then
        let displayString = viewModel.messages.last?.tokenMetrics?.displayString ?? ""
        XCTAssertTrue(displayString.contains("42 tokens"))
        XCTAssertTrue(displayString.contains("15.5 tok/s"))
        XCTAssertTrue(displayString.contains("2.7s"))
    }
    
    // MARK: - Performance Tracking Tests
    
    func testTokenGenerationSpeedTracking() async {
        // Given
        let startTime = Date()
        var metrics = TokenMetrics()
        
        // Simulate token generation over 2 seconds
        let tokenUpdates = [
            (tokens: 5, delay: 0.2),
            (tokens: 15, delay: 0.5),
            (tokens: 30, delay: 1.0),
            (tokens: 50, delay: 1.5),
            (tokens: 60, delay: 2.0)
        ]
        
        // When
        for update in tokenUpdates {
            let updateTime = startTime.addingTimeInterval(update.delay)
            metrics.update(tokenCount: update.tokens, currentTime: updateTime)
            
            // Verify incremental speed calculations
            if update.tokens > 5 {
                XCTAssertGreaterThan(metrics.currentTokensPerSecond, 0)
                XCTAssertGreaterThan(metrics.averageTokensPerSecond, 0)
            }
        }
        
        // Then
        metrics.finalize()
        XCTAssertEqual(metrics.totalTokens, 60)
        XCTAssertEqual(metrics.totalGenerationTime, 2.0, accuracy: 0.1)
        XCTAssertEqual(metrics.averageTokensPerSecond, 30.0, accuracy: 2.0)
    }
    
    // MARK: - Edge Cases
    
    func testEmptyResponseWithMetrics() {
        // Given
        var metrics = TokenMetrics()
        metrics.update(tokenCount: 0, currentTime: Date())
        
        let message = ChatMessage(
            content: "",
            role: .assistant,
            timestamp: Date(),
            modelUsed: "Test Model",
            tokenMetrics: metrics
        )
        
        // When
        viewModel.messages.append(message)
        
        // Then
        XCTAssertEqual(viewModel.messages.last?.content, "")
        XCTAssertEqual(viewModel.messages.last?.tokenMetrics?.totalTokens, 0)
        XCTAssertEqual(viewModel.messages.last?.tokenMetrics?.displayString, "")
    }
    
    func testLongRunningGeneration() async {
        // Simulate a long generation (30+ seconds)
        var metrics = TokenMetrics()
        let startTime = Date()
        
        // Generate 500 tokens over 30 seconds
        for i in stride(from: 1, through: 500, by: 10) {
            let time = startTime.addingTimeInterval(Double(i) * 0.06) // ~16.7 tok/s
            metrics.update(tokenCount: i, currentTime: time)
        }
        
        metrics.finalize()
        
        XCTAssertEqual(metrics.totalTokens, 491) // Last value in stride
        XCTAssertGreaterThan(metrics.totalGenerationTime, 29.0)
        XCTAssertLessThan(metrics.totalGenerationTime, 31.0)
        XCTAssertEqual(metrics.averageTokensPerSecond, 16.7, accuracy: 1.0)
    }
}

// MARK: - Mock AIInferenceManager

class MockAIInferenceManager: AIInferenceManager {
    var shouldFailLoading = false
    var mockStreamingResponses: [StreamingResponse] = []
    
    override func loadModel(_ model: AIModel) async throws {
        if shouldFailLoading {
            throw AIInferenceError.modelNotLoaded
        }
        // Simulate successful loading
        await MainActor.run {
            self.isModelLoaded = true
        }
    }
    
    override func generateStreamingTextWithMetrics(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) -> AsyncStream<StreamingResponse> {
        
        return AsyncStream { continuation in
            Task {
                for response in mockStreamingResponses {
                    continuation.yield(response)
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                }
                continuation.finish()
            }
        }
    }
    
    /// Helper to create mock streaming responses
    func createMockResponses(tokenCount: Int, duration: TimeInterval) {
        mockStreamingResponses.removeAll()
        var metrics = TokenMetrics()
        let startTime = Date()
        
        for i in 1...tokenCount {
            let progress = Double(i) / Double(tokenCount)
            let currentTime = startTime.addingTimeInterval(duration * progress)
            metrics.update(tokenCount: i, currentTime: currentTime)
            
            let text = i % 5 == 0 ? "word " : ""
            let response = StreamingResponse(text: text, metrics: metrics)
            mockStreamingResponses.append(response)
        }
        
        // Final metrics update
        metrics.finalize()
        mockStreamingResponses.append(StreamingResponse(text: "", metrics: metrics))
    }
}