# System Patterns

**Date:** 2025-07-21
**Tags:** architecture, patterns, swiftui

## Application Architecture

The application is structured around a tab-based navigation system in SwiftUI, with each tab representing a core feature set.

- **`ChatTab`:** Handles the user-facing chat interface (`ChatView.swift`).
- **`DownloadTab`:** Manages model discovery and downloading (`DownloadView.swift`, `ModelDownloadManager.swift`).
- **`SettingsTab`:** Provides user-configurable options (`StorageSettingsView.swift`).

## Key Design Patterns

### State Management

- **`ObservableObject`:** The `ModelManager` class is implemented as an `@MainActor` observable object to manage and publish the state of downloaded models and loading statuses. This allows SwiftUI views to automatically update when the state changes.

```swift
@MainActor
class ModelManager: ObservableObject {
    @Published var downloadedModels: [String] = []
    @Published var isLoading = false
    
    func refreshModels() {
        isLoading = true
        // Refresh logic here
        isLoading = false
    }
}
```

### File System Interaction

- **`FileManager`:** Standard `FileManager` APIs are used for directory creation and file enumeration.
- **Directory Structure:** The application expects a specific directory (`Documents/MLXModels`) to store model files. A helper function is used to create this directory if it doesn't exist.

```swift
func createDirectoryIfNeeded(at path: String) {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: path) {
        try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
}
```

- **Model Detection:** Models are identified by enumerating the contents of the `MLXModels` directory.

```swift
func getDownloadedModels() -> [String] {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let modelsPath = documentsPath.appendingPathComponent("MLXModels")
    
    guard FileManager.default.fileExists(atPath: modelsPath.path) else { return [] }
    
    do {
        return try FileManager.default.contentsOfDirectory(atPath: modelsPath.path)
    } catch {
        return []
    }
}
```
