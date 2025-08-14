# Technology Stack

## Platform & Framework
- **iOS 15.0+** - Target platform
- **SwiftUI** - Native UI framework throughout the application
- **SwiftData** - Data persistence for conversations and chat messages
- **Xcode 15.0+** - Development environment

## Core Dependencies
- **MLX Swift (v0.25.6)** - Apple's machine learning framework for on-device inference
- **MLX Swift Examples (v2.25.5)** - Reference implementations and utilities
- **Swift Transformers (v0.1.22)** - Hugging Face transformers for Swift
- **Jinja (v1.2.2)** - Template engine for chat formatting
- **GzipSwift (v6.0.1)** - Compression utilities

## Supporting Libraries
- **Swift Collections (v1.2.1)** - Advanced collection types
- **Swift Numerics (v1.0.3)** - Numerical computing utilities
- **Swift Argument Parser (v1.4.0)** - Command line argument parsing

## Architecture Patterns
- **MVVM** - Model-View-ViewModel pattern with SwiftUI
- **Coordinator Pattern** - Navigation and flow management
- **Strategy Pattern** - Download strategies for different model formats
- **Dependency Injection** - Protocol-based dependency management
- **Repository Pattern** - Data access abstraction

## Code Quality Tools
- **SwiftLint** - Code style enforcement with custom rules
- **Build Server Protocol** - IDE integration via xcode-build-server

## Common Commands

### Building
```bash
# Open project in Xcode
open "Offline AI&ML Playground.xcodeproj"

# Build from command line
xcodebuild -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" build
```

### Testing
```bash
# Run tests
xcodebuild test -project "Offline AI&ML Playground.xcodeproj" -scheme "Offline AI&ML Playground" -destination "platform=iOS Simulator,name=iPhone 15"

# Note: MLX functionality requires physical device testing
```

### Code Quality
```bash
# Run SwiftLint
swiftlint lint

# Auto-fix SwiftLint issues
swiftlint --fix

# Run SwiftLint script
./Scripts/swiftlint.sh
```

## Development Notes
- **Physical device required** for MLX Swift testing - simulators will crash
- **Apple Silicon recommended** for optimal development experience
- **Memory management critical** - proper cleanup required for model loading/unloading
- **Background processing** - Use async/await for model operations to avoid blocking UI