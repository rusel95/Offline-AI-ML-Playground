# Offline AI&ML Playground - App Architecture

**Date:** 2025-07-20  
**Tags:** architecture, swift, swiftui, mlx, structure

## Overview
Swift/SwiftUI application for offline AI model management and interaction.

## App Structure

### Main Tabs
- **ChatTab**: AI conversation interface
  - `ChatView.swift` - Main chat UI component
- **DownloadTab**: Model management system
  - `DownloadView.swift` - Download interface
  - `ModelDownloadManager.swift` - Download logic and model handling
- **SettingsTab**: App configuration
  - `StorageSettingsView.swift` - Storage and file management settings

## File System Structure
```
Offline AI&ML Playground/
├── ChatTab/
│   └── Views/
│       └── ChatView.swift
├── DownloadTab/
│   ├── Views/
│   │   └── DownloadView.swift
│   └── ModelDownloadManager.swift
├── SettingsTab/
│   └── Views/
│       └── StorageSettingsView.swift
└── Documents/
    └── MLXModels/ (MISSING - causes model detection issues)
```

## Technology Stack
- **Language**: Swift
- **Framework**: SwiftUI
- **AI Models**: MLX format
- **Platform**: iOS/macOS

## Key Components
- Model download and management
- Local AI chat interface
- Storage configuration
- File system integration for model storage
