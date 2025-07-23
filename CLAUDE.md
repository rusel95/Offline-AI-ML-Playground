# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **iOS app called "Offline AI & ML Playground"** that enables users to run AI models locally on their devices using Apple's MLX Swift framework. The app provides a complete offline AI experience with model downloading, chat interface, and performance monitoring.

## Key Architecture

### Core Technologies
- **MLX Swift**: Apple's machine learning framework for on-device inference
- **SwiftUI**: Modern iOS UI framework throughout the entire app
- **Swift Package Manager**: Dependencies managed via Xcode project
- **HuggingFace Integration**: Models sourced from HuggingFace Hub

### App Structure
- **TabView Architecture**: Three main tabs (Chat, Download, Settings)
- **ChatTab/**: Real-time chat interface with streaming AI responses
- **DownloadTab/**: Model discovery, download, and management
- **SettingsTab/**: Performance monitoring and app configuration
- **Shared/**: Core models (`AIModel`, `ModelDownloadManager`, `SharedModelManager`)

### Key Components
1. **AIInferenceManager** (`DownloadTab/AIInferenceManager.swift`): Core MLX Swift integration for running models
2. **AIModel** (`Shared/AIModel.swift`): Model definitions with provider detection and memory estimates
3. **ModelDownloadManager** (`Shared/ModelDownloadManager.swift`): Handles model downloading from HuggingFace
4. **SharedModelManager** (`Shared/SharedModelManager.swift`): Coordinates between download and inference systems

## Development Commands

### Build and Run
```bash
# Open the Xcode project
open "Offline AI&ML Playground.xcodeproj"

# Build from command line (if xcodebuild is available)
xcodebuild -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -configuration Debug
```

### Testing
```bash
# Run unit tests
xcodebuild test -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test files
# - ModelLoadingTests.swift: Tests for model loading functionality
# - Offline_AI_ML_PlaygroundTests.swift: General app tests
```

### Project Structure Navigation
- Main app code: `Offline AI&ML Playground/`
- Test files: `Offline AI&ML PlaygroundTests/` and `Offline AI&ML PlaygroundUITests/`
- Documentation: `memory-bank/` contains project context and progress
- Assets: `Offline AI&ML Playground/Assets.xcassets/`

## Important Technical Details

### MLX Swift Integration
- Uses multiple MLX Swift packages: `MLX`, `MLXNN`, `MLXLLM`, `MLXLMCommon`, etc.
- Models are loaded using `LLMModelFactory` and `ModelContainer`
- Streaming text generation via `MLXLMCommon.generate()`
- Memory management is critical - proper cleanup required between model loads

### Model Management
- Models downloaded to `Documents/Models/` directory
- Local caching system to avoid re-downloads
- Support for various model formats (GGUF, SafeTensors, MLX native)
- Model switching without app restart

### Memory Considerations
- iOS memory constraints require careful model selection
- Built-in memory pressure monitoring
- Automatic cleanup of MLX resources
- Memory usage tracking via `getMemoryUsage()` in AIInferenceManager

### File System Structure
```
Offline AI&ML Playground/
├── App/AppView.swift                    # Main app entry point
├── ChatTab/                            # Chat interface components
├── DownloadTab/                        # Model download and management
├── SettingsTab/                        # App settings and monitoring
├── Shared/                             # Shared data models and managers
└── Documents/MLXModels/                # Downloaded model storage
```

## Development Patterns

### SwiftUI Patterns
- Extensive use of `@StateObject` and `@ObservedObject` for reactive UI
- Custom view components with consistent styling
- Navigation via TabView and NavigationStack

### Async/Await Usage
- All model operations use Swift concurrency (`async`/`await`)
- Streaming responses via `AsyncStream`
- Proper error handling with custom `AIInferenceError` types

### Model Provider Detection
- Automatic detection of model providers (Meta, Mistral, DeepSeek, etc.)
- Brand-specific icons and colors in `AIModel.swift`
- Dynamic model discovery from HuggingFace API

## Common Tasks

### Adding New Model Support
1. Update `AIModel.swift` provider detection logic
2. Add MLX configuration mapping in `createModelConfigurationForDownloadedModel()`
3. Test model loading in `AIInferenceManager`

### UI Updates
- All UI is SwiftUI-based, follow existing patterns in `ChatTab/Views/` and `DownloadTab/Views/`
- Use `@MainActor` for UI updates from background threads
- Maintain consistent styling with existing components

### Testing New Features
- Use the test files in `ModelLoadingTests.swift` for model-related functionality
- UI tests are in `Offline AI&ML PlaygroundUITests/`
- Manual testing via iOS Simulator or device

## Performance Optimization
- Monitor memory usage via Settings > Performance tab
- Use streaming for better UX during long generations
- Implement proper model cleanup between switches
- Consider model quantization levels for iOS devices