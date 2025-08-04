# SOLID and DRY Principles Guidelines for Offline AI & ML Playground

## Overview
This document outlines the SOLID and DRY principles that must be followed in the codebase to ensure maintainability, testability, and scalability.

## SOLID Principles

### 1. Single Responsibility Principle (SRP)
**A class should have only one reason to change.**

#### Guidelines:
- Each class should focus on a single, well-defined purpose
- Avoid mixing UI logic with business logic
- Separate concerns like networking, storage, and computation
- ViewModels should only manage UI state, not perform complex operations

#### Examples in our codebase:
- ✅ `ModelLoader` - Only handles model loading/unloading
- ✅ `InferenceEngine` - Only handles text generation
- ✅ `MemoryManager` - Only handles memory monitoring
- ✅ `StorageCalculator` - Only handles storage calculations
- ✅ `DownloadService` - Only handles download operations

#### Anti-patterns to avoid:
- ❌ Classes with more than 10 @Published properties
- ❌ ViewModels directly performing file operations
- ❌ Single class handling multiple file formats
- ❌ Mixing network and storage operations in one class

### 2. Open/Closed Principle (OCP)
**Software entities should be open for extension but closed for modification.**

#### Guidelines:
- Use protocols and abstract types for extensibility
- Implement strategy pattern for different model formats
- Use dependency injection for swappable implementations
- Avoid switch statements that need modification for new cases

#### Implementation approach:
```swift
// Protocol for different download strategies
protocol DownloadStrategy {
    func download(model: AIModel) async throws -> URL
}

// Concrete implementations
class GGUFDownloadStrategy: DownloadStrategy { }
class SafetensorsDownloadStrategy: DownloadStrategy { }
class MultiPartDownloadStrategy: DownloadStrategy { }
```

### 3. Liskov Substitution Principle (LSP)
**Derived classes must be substitutable for their base classes.**

#### Guidelines:
- Subclasses should not break parent class contracts
- Protocol implementations must fulfill all requirements
- Avoid throwing exceptions in overridden methods if parent doesn't
- Maintain consistent behavior across implementations

### 4. Interface Segregation Principle (ISP)
**Clients should not be forced to depend on interfaces they don't use.**

#### Guidelines:
- Create focused, specific protocols instead of large ones
- Split protocols when they serve multiple purposes
- Don't force implementations to provide empty methods

#### Examples:
```swift
// Good: Segregated protocols
protocol ModelLoadable {
    func loadModel(_ model: AIModel) async throws
}

protocol TextGeneratable {
    func generateText(prompt: String) async throws -> String
}

// Bad: Fat interface
protocol ModelManager {
    func loadModel(_ model: AIModel) async throws
    func generateText(prompt: String) async throws -> String
    func downloadModel(_ model: AIModel) async throws
    func deleteModel(_ modelId: String) throws
    // Too many responsibilities
}
```

### 5. Dependency Inversion Principle (DIP)
**Depend on abstractions, not concretions.**

#### Guidelines:
- High-level modules should not depend on low-level modules
- Both should depend on abstractions (protocols)
- Use dependency injection for dependencies
- Avoid creating instances directly in classes

#### Implementation:
```swift
// Good: Depending on abstraction
class ChatViewModel {
    private let inferenceService: ModelInferenceProtocol
    private let storageService: StorageManagerProtocol
    
    init(inferenceService: ModelInferenceProtocol,
         storageService: StorageManagerProtocol) {
        self.inferenceService = inferenceService
        self.storageService = storageService
    }
}

// Bad: Depending on concrete implementation
class ChatViewModel {
    private let inferenceManager = AIInferenceManager() // Direct dependency
}
```

## DRY (Don't Repeat Yourself) Principle

### Guidelines:
1. **Extract common functionality into shared utilities**
   - Storage calculations → `StorageCalculator`
   - Memory management → `MemoryManager`
   - Download progress tracking → `DownloadProgressTracker`
   - Error types → `ModelErrors.swift`

2. **Avoid code duplication**
   - Use shared error enums instead of duplicating
   - Create utility functions for repeated operations
   - Use extensions for common functionality

3. **Centralize configuration**
   - Model paths and directories
   - Network timeouts and retry logic
   - Memory thresholds and limits

### Common Utilities Created:

#### Core/Errors/ModelErrors.swift
- Unified error types for the entire app
- Prevents duplicate error enums

#### Core/Memory/MemoryManager.swift
- Centralized memory monitoring
- Shared memory calculation logic

#### Core/Storage/StorageCalculator.swift
- All storage calculations in one place
- Consistent formatting of sizes

#### Core/Downloads/DownloadProgressTracker.swift
- Reusable download progress tracking
- Speed calculation and ETA estimation

#### Protocols/ModelLoaderProtocol.swift
- Common interfaces for dependency injection
- Enables testability and flexibility

## Implementation Checklist

When adding new code:
- [ ] Does each class have a single, clear responsibility?
- [ ] Can new features be added without modifying existing code?
- [ ] Are protocols focused and specific?
- [ ] Are dependencies injected rather than created?
- [ ] Is common functionality extracted to utilities?
- [ ] Are error types using the shared enums?
- [ ] Is storage/memory calculation using shared utilities?

## Refactoring Priority

1. **High Priority**
   - Split `AIInferenceManager` into focused components ✅
   - Extract shared error types ✅
   - Create memory management utilities ✅
   - Implement dependency injection in ViewModels

2. **Medium Priority**
   - Implement strategy pattern for download formats
   - Create protocol-based architecture for services
   - Extract common UI components

3. **Low Priority**
   - Minor code duplications
   - Optimization of existing utilities

## Benefits

Following these principles provides:
- **Maintainability**: Easier to understand and modify
- **Testability**: Components can be tested in isolation
- **Scalability**: New features don't break existing code
- **Reusability**: Components can be reused across the app
- **Consistency**: Uniform patterns throughout the codebase