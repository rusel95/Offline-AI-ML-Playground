# Chat Memory Feature Implementation

## Overview
The chat memory feature has been successfully implemented to provide conversation context to the AI models. This allows the models to maintain continuity across multiple messages within a conversation. By default, the system now uses the maximum context window available for each model.

## Key Components

### 1. Model Context Windows
Each model now has a defined maximum context window (in tokens):
- Small models (GPT-2, DistilBERT): 512-1024 tokens
- Medium models (TinyLlama, Phi-2): 2048-4096 tokens
- Large models (Mistral, Llama-3.2): 8192 tokens
- Extended context models (Phi-3-128k): 131,072 tokens

### 2. ChatViewModel Updates
- Added `useMaxContext` property (default: true) to use full model context
- Added `customContextSize` for optional message limiting
- Token-based context building with overflow prevention
- Simple token estimation (approximately 4 characters per token)

### 3. Conversation Context Building
- Intelligent context building that includes as many messages as possible
- Token counting to prevent exceeding model limits
- Reserve buffer (200 tokens) for model responses
- Reverse chronological inclusion (most recent messages prioritized)

### 4. User Interface Enhancements
- "Memory Settings" menu with model-specific information
- Toggle between "Use Maximum Context" and custom message limits
- Visual indicator showing token capacity for current model
- Real-time display of memory mode (full context vs custom limit)

## How It Works

1. **Maximum Context Mode** (Default):
   - System calculates available tokens (model max - response buffer)
   - Includes messages from newest to oldest until token limit reached
   - Provides maximum continuity within model constraints

2. **Custom Limit Mode**:
   - User can limit to specific message counts (5, 10, 20, 50)
   - Still respects token limits to prevent overflow
   - Useful for testing or reducing context noise

3. **Token Estimation**:
   - Approximately 4 characters = 1 token (rough estimate)
   - Conservative approach to prevent overflow
   - Actual tokenization varies by model

## User Experience

- **Default Behavior**: Full context utilization for maximum memory
- **Model-Aware**: Each model uses its optimal context window
- **Transparent**: UI shows current memory mode and capacity
- **Flexible**: Users can switch between max context and custom limits

## Technical Implementation

```swift
// Token estimation
private func estimateTokenCount(_ text: String) -> Int {
    return max(1, text.count / 4)
}

// Context building with token awareness
if estimatedTokens + messageTokens < availableTokens {
    includedMessages.insert(message, at: 0)
    estimatedTokens += messageTokens
}
```

## Performance Considerations

- Token counting is performed efficiently during context building
- Messages are included until token limit is reached
- Response buffer ensures models have space to generate
- No performance impact on inference speed

## Benefits

1. **Maximum Memory**: Uses all available context for better continuity
2. **Model-Specific**: Each model operates at its optimal capacity
3. **Overflow Prevention**: Token counting prevents context truncation
4. **User Control**: Option to limit context when needed