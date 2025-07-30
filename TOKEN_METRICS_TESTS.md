# Token Metrics Tests Documentation

## Overview
This document describes the test suite for the token metrics feature in the Offline AI&ML Playground app.

## Test Files

### 1. TokenMetricsTests.swift
Tests the core `TokenMetrics` struct functionality:
- **Initialization**: Verifies default values
- **Token Updates**: Tests token counting and rate calculation
- **Time Tracking**: Validates time to first token and total generation time
- **Display Formatting**: Ensures correct string formatting
- **Edge Cases**: Handles zero tokens, rapid updates, etc.
- **Performance**: Measures update performance

### 2. StreamingResponseTests.swift
Tests the `StreamingResponse` struct and streaming behavior:
- **Response Creation**: Validates text and metrics pairing
- **Streaming Sequences**: Tests realistic streaming scenarios
- **Integration**: Verifies ChatMessage compatibility
- **Performance Variations**: Tests variable generation rates
- **Edge Cases**: Handles empty responses and rapid updates

### 3. ChatViewModelTokenTests.swift
Integration tests for token tracking in ChatViewModel:
- **Message Creation**: Verifies metrics initialization
- **Live Updates**: Tests metrics updates during streaming
- **Display Integration**: Validates UI string generation
- **Performance Tracking**: Tests real-world speed calculations
- **Mock Infrastructure**: Includes MockAIInferenceManager for testing

## Running the Tests

### Command Line
```bash
# Run all tests
xcodebuild test -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test class
xcodebuild test -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:Offline_AI_ML_PlaygroundTests/TokenMetricsTests
```

### Xcode
1. Open the project in Xcode
2. Press `Cmd+U` to run all tests
3. Or navigate to specific test file and click the diamond next to test methods

## Test Coverage

### Business Logic Covered:
- ✅ Token counting accuracy
- ✅ Speed calculation (tokens/second)
- ✅ Time to first token measurement
- ✅ Average vs current speed tracking
- ✅ Display string formatting
- ✅ Streaming response handling
- ✅ ChatMessage integration
- ✅ Edge cases and error handling

### Key Test Scenarios:
1. **Normal Generation**: 10-50 tokens at 10-20 tok/s
2. **Fast Generation**: 100+ tokens at 50+ tok/s
3. **Slow Generation**: <5 tok/s
4. **Long Running**: 30+ second generations
5. **Empty/Failed**: Zero token responses

## Mock Objects

### MockAIInferenceManager
Simulates the AI inference manager for testing:
- Configurable streaming responses
- Controllable failure scenarios
- Predictable token generation patterns

## Performance Benchmarks

Expected performance metrics from tests:
- Token update operation: <0.001s
- Display string generation: <0.0001s
- 1000 token updates: <0.1s total

## Best Practices

1. **Test Isolation**: Each test is independent
2. **Async Testing**: Proper use of expectations and async/await
3. **Mock Data**: Realistic token generation patterns
4. **Edge Cases**: Comprehensive edge case coverage
5. **Performance**: Includes performance measurement tests