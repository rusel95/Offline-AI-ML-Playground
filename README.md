# 🧪 Offline AI & ML Playground

An **AI/ML experimentation playground** for Apple platforms (iOS, iPadOS, macOS) focused on **testing, comparing, and benchmarking on-device LLMs**. Built with native SwiftUI + TCA-style architecture.

## 🎯 Core Focus: AI/ML Experimentation

This is **not a chat app** - it's a **developer playground** for AI/ML research and testing.

### ✨ Key Features

- **🔬 Model Experimentation** - Test different prompts, parameters, and approaches
- **📊 Performance Benchmarking** - Measure inference time, tokens/sec, memory usage
- **⚖️ Model Comparison** - Side-by-side comparison of different models
- **🔧 Parameter Tuning** - Experiment with temperature, top-p, repetition penalty
- **📈 Batch Processing** - Run multiple prompts efficiently
- **💾 Experiment Tracking** - Save and replay experiments

## 🏗️ Architecture: TCA-Style with Native Tools

Uses **TCA principles** (State + Actions + Reducers) implemented with pure SwiftUI + Combine:

```
📁 Core/
├── PlaygroundArchitecture.swift  # TCA-style architecture (native)
├── Dependencies.swift            # Service layer

📁 Models/
├── AIModel.swift                # Model definitions
├── AIExperiment.swift           # Experiment tracking

📁 Playground/
├── ExperimentView.swift         # Main experimentation interface
├── ModelComparisonView.swift    # Side-by-side model testing
├── BenchmarkView.swift          # Performance testing
├── ParameterTuningView.swift    # Parameter experimentation

📁 Interfaces/
├── ChatInterface.swift          # Simple chat (using existing framework)
├── PromptInterface.swift        # Direct prompt testing
├── BatchInterface.swift         # Batch processing
```

## 🎮 Interface Methods

The playground supports multiple ways to interact with AI models:

### 1. **💬 Chat Interface** (Using Existing Framework)
- Simple conversation interface
- Built with established SwiftUI chat libraries
- Focus: Quick model interaction

### 2. **📝 Prompt Interface** 
- Direct prompt → response testing
- Parameter adjustment in real-time
- Focus: Prompt engineering

### 3. **📦 Batch Interface**
- Process multiple prompts at once
- CSV import/export
- Focus: Systematic testing

### 4. **⚖️ Comparison Interface**
- Side-by-side model comparison
- Same prompt, different models
- Focus: Model evaluation

### 5. **📊 Benchmark Interface**
- Performance testing suite
- Token/sec measurements
- Focus: Performance analysis

## 🚀 Recommended Chat Framework Integration

Instead of building chat from scratch, integrate with:

```swift
// Option 1: ChatUI (if available)
import ChatUI

struct ChatInterface: View {
    @StateObject private var playground = AppPlaygroundReducer()
    
    var body: some View {
        ChatView(
            messages: chatMessages,
            onSend: { message in
                playground.send(.generateResponse(message, .default))
            }
        )
    }
}

// Option 2: Custom lightweight chat
struct SimpleChat: View {
    @State private var messages: [ChatMessage] = []
    @State private var input: String = ""
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
            }
            
            HStack {
                TextField("Message", text: $input)
                Button("Send") { sendMessage() }
            }
        }
    }
}
```

## 🧪 Experiment Examples

```swift
// Quick parameter testing
let experiment = AIExperiment(
    name: "Temperature Test",
    prompts: ["Explain quantum computing"],
    parameters: [
        .init(temperature: 0.2),  // Factual
        .init(temperature: 0.7),  // Balanced  
        .init(temperature: 0.9)   // Creative
    ]
)

// Model comparison
playground.send(.compareModels(
    [llamaModel, gemmaModel, mistralModel],
    prompt: "Write a haiku about AI",
    parameters: .creative
))

// Batch processing
playground.send(.runBatchInference([
    "What is machine learning?",
    "Explain neural networks",
    "How does backpropagation work?"
], parameters: .factual))
```

## 🎯 Development Priorities

1. **✅ Core Architecture** - TCA-style with native tools
2. **✅ Model Management** - Load/unload/switch models
3. **🔄 Simple Chat Integration** - Use existing framework
4. **🔄 Experiment Framework** - Save/load experiments
5. **⏳ Performance Metrics** - Real-time measurements
6. **⏳ Model Comparison** - Side-by-side testing
7. **⏳ Batch Processing** - Automated testing

## 📦 Dependencies

**Native Apple Frameworks Only:**
- SwiftUI (UI)
- Combine (Reactive programming)
- Foundation (Core functionality)

**Optional Chat Framework:**
- Research existing SwiftUI chat libraries
- Or implement minimal chat interface

## 🎮 Usage Example

```swift
@main
struct PlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            PlaygroundView()
                .environmentObject(AppPlaygroundReducer())
        }
    }
}

struct PlaygroundView: View {
    @EnvironmentObject var playground: AppPlaygroundReducer
    
    var body: some View {
        TabView {
            ExperimentView()
                .tabItem { Label("Experiment", systemImage: "flask") }
            
            ModelComparisonView()
                .tabItem { Label("Compare", systemImage: "scale.3d") }
            
            BenchmarkView()
                .tabItem { Label("Benchmark", systemImage: "speedometer") }
        }
    }
}
```

---

**This is a playground for AI/ML experimentation, not a production chat app.** 🧪🚀 