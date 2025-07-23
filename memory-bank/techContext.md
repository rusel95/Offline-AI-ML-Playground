# Technology Context

**Date:** 2025-07-21
**Tags:** tech-stack, swift, swiftui, mlx

## Core Technologies

- **Language:** Swift
- **UI Framework:** SwiftUI
- **AI/ML Framework:** MLX Swift (Apple's machine learning framework)
- **AI/ML Models:** MLX format, GGUF, SafeTensors
- **Platform:** iOS (requires physical device)

## Development Environment

- **IDE:** Xcode 15.0+
- **Dependencies:** Swift Package Manager (MLX, MLXNN, MLXLLM, MLXLMCommon, MLXRandom)
- **Target:** iOS 15.0+

## Critical Technical Constraints

### **iOS Simulator Limitation (IMPORTANT)**
- **MLX Swift does NOT support iOS simulators** due to GPU/Metal framework limitations
- **Simulators will crash** when attempting to load AI models - this is expected behavior
- **Physical iOS devices required** for all MLX-related functionality testing
- **Development workflow:** Use simulators for UI-only testing, physical devices for AI features

### **Hardware Requirements**
- **Apple Silicon recommended** for optimal performance
- **Metal-compatible GPU** required for MLX Swift inference
- **2GB+ free storage** for model downloads
- **Physical iOS device** mandatory for MLX functionality

### **Other Constraints**
- **Offline-First:** The application must be designed to function without a persistent internet connection
- **Local Storage:** Models and user data are stored directly on the user's device
- **Performance:** The application needs to be responsive even while managing large model files
- **Memory Management:** Proper MLX resource cleanup required to prevent memory leaks
