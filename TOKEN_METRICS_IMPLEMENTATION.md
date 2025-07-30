# Token Metrics Implementation

## Overview
This document describes the implementation of token measurement feature in the Offline AI&ML Playground app. The feature displays real-time token generation metrics during AI model responses.

## Implementation Details

### 1. TokenMetrics Struct (`Shared/TokenMetrics.swift`)
- Tracks total tokens, generation speed, and timing
- Provides formatted display string
- Updates metrics in real-time during streaming
- Calculates both instantaneous and average tokens/second

### 2. AIInferenceManager Updates
- Added `generateStreamingTextWithMetrics()` function
- Returns `StreamingResponse` with both text and metrics
- Tracks token count from MLX's generate callback
- Measures time to first token and total generation time

### 3. ChatMessage Model Updates
- Added optional `tokenMetrics` property
- Preserves metrics with message history

### 4. ChatViewModel Updates
- Uses new streaming function with metrics
- Updates both content and metrics during streaming
- Maintains metrics state throughout generation

### 5. ChatMessageView UI Updates
- Displays metrics below message content
- Shows format: "X tokens • Y tok/s • Z.Zs"
- Only visible for assistant messages
- Uses smaller, secondary text style

## Usage

When a user sends a message, the app will:
1. Start tracking metrics when generation begins
2. Update token count and speed in real-time
3. Display live metrics during streaming
4. Show final metrics after completion

## Example Display
```
127 tokens • 14.3 tok/s • 8.9s
```

## Technical Notes

- Token counting uses MLX's built-in tokenizer
- Timing uses high-resolution Date() for accuracy
- Smoothing algorithm prevents jumpy rate display
- Metrics persist with conversation history

## Future Enhancements

Potential improvements:
- Token usage limits/warnings
- Cost estimation based on token count
- Performance graphs over time
- Model comparison metrics