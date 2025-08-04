# SOLID and DRY Principles Guidelines

## Overview

This document outlines the SOLID and DRY principles that must be followed in this codebase. All new code additions and modifications must adhere to these principles.

## SOLID Principles

### 1. Single Responsibility Principle (SRP)
- Each class should have only one reason to change
- Components should focus on a single task or responsibility
- Large classes should be split into smaller, focused components

**Example Implementation:**
- Split `AIInferenceManager` into:
  - `ModelLoader` - handles model loading/unloading
  - `InferenceEngine` - handles text generation
  - `AIInferenceCoordinator` - coordinates between components

### 2. Open/Closed Principle (OCP)
- Classes should be open for extension but closed for modification
- Use protocols and inheritance to add new functionality
- Implement strategy pattern for varying behaviors

**Example Implementation:**
- `DownloadStrategy` protocol with implementations:
  - `GGUFDownloadStrategy`
  - `SafetensorsDownloadStrategy`
  - `MLXDownloadStrategy`
  - `MultiPartDownloadStrategy`

### 3. Liskov Substitution Principle (LSP)
- Derived classes must be substitutable for their base classes
- Protocol implementations should fulfill the contract completely
- Avoid throwing unexpected exceptions

### 4. Interface Segregation Principle (ISP)
- Clients should not depend on interfaces they don't use
- Break large protocols into smaller, focused ones
- Create role-specific protocols

**Example Implementation:**
```swift
protocol ModelLoaderProtocol { }
protocol ModelInferenceProtocol { }
protocol ModelConfigurationProtocol { }
protocol DownloadManagerProtocol { }
protocol StorageManagerProtocol { }
```

### 5. Dependency Inversion Principle (DIP)
- Depend on abstractions, not concretions
- High-level modules should not depend on low-level modules
- Both should depend on abstractions

**Example Implementation:**
```swift
class ChatViewModel {
    init(
        modelCatalog: ModelCatalogProtocol,
        inferenceService: ModelInferenceProtocol,
        conversationManager: ConversationManagerProtocol,
        contextBuilder: ContextBuilderProtocol
    )
}
```

## DRY (Don't Repeat Yourself) Principle

### Guidelines:
1. **Extract Common Functionality**
   - Create shared utilities for repeated operations
   - Use protocols for common interfaces
   - Centralize configuration and constants

2. **Shared Components Created:**
   - `MemoryManager` - centralized memory monitoring
   - `StorageCalculator` - unified storage calculations
   - `DownloadProgressTracker` - consistent progress tracking
   - `ModelPaths` - centralized path management

3. **Error Handling:**
   - Use centralized error types (e.g., `ModelError`, `AIInferenceError`)
   - Avoid duplicate error definitions
   - Consistent error messages and handling

## Implementation Checklist

### When Adding New Code:
- [ ] Does each class have a single responsibility?
- [ ] Are dependencies injected rather than created internally?
- [ ] Are protocols used instead of concrete types?
- [ ] Is common functionality extracted to shared utilities?
- [ ] Are error types reused rather than duplicated?
- [ ] Can the code be extended without modification?

### When Refactoring:
- [ ] Identify classes with multiple responsibilities
- [ ] Extract interfaces (protocols) from implementations
- [ ] Replace direct instantiation with dependency injection
- [ ] Move duplicate code to shared utilities
- [ ] Create strategies for varying behaviors

## Architecture Patterns

### 1. Coordinator Pattern
- Separates navigation logic from view controllers
- Example: `AIInferenceCoordinator`

### 2. Strategy Pattern
- Encapsulates algorithms and makes them interchangeable
- Example: Download strategies for different file formats

### 3. Factory Pattern
- Creates objects without specifying exact classes
- Example: `DownloadStrategyFactory`

### 4. Observer Pattern
- Using Combine for reactive updates
- Example: Published properties in ViewModels

## Code Organization

### Directory Structure:
```
Shared/
├── Core/
│   ├── Protocols/       # All protocol definitions
│   ├── Memory/          # Memory management utilities
│   ├── Storage/         # Storage utilities
│   ├── Downloads/       # Download management
│   │   └── Strategies/  # Download strategy implementations
│   └── Inference/       # AI inference components
├── Models/              # Data models
└── Utilities/           # Shared utilities
```

### Naming Conventions:
- Protocols: Suffix with `Protocol`
- Implementations: Clear, descriptive names
- Utilities: Suffix with `Manager`, `Calculator`, etc.

## Testing Considerations

### Unit Testing:
- Test each component in isolation
- Mock dependencies using protocols
- Test edge cases and error conditions

### Integration Testing:
- Test component interactions
- Verify proper dependency injection
- Test complete workflows

## Continuous Improvement

1. **Regular Reviews:**
   - Identify code smells
   - Look for duplication
   - Check adherence to principles

2. **Refactoring:**
   - Extract methods when functions grow large
   - Create abstractions for repeated patterns
   - Split classes that violate SRP

3. **Documentation:**
   - Document architectural decisions
   - Explain complex abstractions
   - Maintain this guidelines document