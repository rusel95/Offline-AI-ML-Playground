# Project Structure

## Root Directory Organization
```
Offline AI&ML Playground/           # Main application target
├── App/                           # Application entry point
├── ChatTab/                       # Chat functionality
├── DownloadTab/                   # Model download management
├── SettingsTab/                   # Application settings
├── Shared/                        # Shared utilities and core logic
├── Assets.xcassets/               # App icons and visual assets
├── Documents/MLXModels/           # Local model storage directory
└── Info.plist                    # App configuration

Offline AI&ML PlaygroundTests/     # Unit and integration tests
Offline AI&ML PlaygroundUITests/   # UI automation tests
```

## Feature-Based Module Structure

### ChatTab Module
```
ChatTab/
├── Models/                        # Data models for chat
├── ViewModels/                    # Chat business logic
└── Views/                         # SwiftUI chat interface components
```

### DownloadTab Module
```
DownloadTab/
├── ViewModels/                    # Download management logic
└── Views/                         # Download UI components
```

### SettingsTab Module
```
SettingsTab/
├── Services/                      # Settings-specific services
├── ViewModels/                    # Settings business logic
└── Views/                         # Settings UI components
```

## Shared Core Architecture
```
Shared/
├── Core/                          # Core business logic
│   ├── Downloads/                 # Download management system
│   │   └── Strategies/            # Strategy pattern implementations
│   ├── Inference/                 # AI model inference engine
│   ├── Memory/                    # Memory management utilities
│   ├── Storage/                   # File system and storage utilities
│   └── Protocols/                 # Core protocol definitions
├── Constants/                     # App-wide constants
├── Protocols/                     # Shared protocol definitions
└── Services/                      # Shared service implementations
```

## Key Architectural Principles

### SOLID & DRY Compliance
- **Single Responsibility** - Each class/module has one clear purpose
- **Strategy Pattern** - Download strategies for different model formats
- **Dependency Injection** - Protocol-based dependencies throughout
- **Shared Utilities** - Common functionality extracted to `Shared/Core/`

### File Naming Conventions
- **ViewModels** - Suffix with `ViewModel` (e.g., `ChatViewModel`)
- **Views** - Suffix with `View` (e.g., `ChatMessageView`)
- **Protocols** - Suffix with `Protocol` (e.g., `ModelLoaderProtocol`)
- **Services** - Suffix with `Service` or `Manager` (e.g., `DownloadService`)
- **Models** - Plain descriptive names (e.g., `AIModel`, `Conversation`)

### Directory Guidelines
- **Feature modules** organized by tab/functionality
- **Shared code** in `Shared/` directory with clear subdirectories
- **Tests** mirror main app structure
- **Assets** centralized in `Assets.xcassets/`
- **Documentation** in root-level markdown files

### Memory Bank Integration
- **Documentation** stored in `memory-bank/` for project context
- **Steering rules** in `.kiro/steering/` for AI assistant guidance
- **Progress tracking** maintained in dedicated markdown files

## Testing Structure
- **Unit tests** for ViewModels and business logic
- **Integration tests** for core workflows
- **UI tests** for critical user journeys
- **Snapshot tests** for UI component verification