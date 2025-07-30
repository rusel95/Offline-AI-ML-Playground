# MLX Model Directory Structure Fix

## Issue Summary
MLX models were failing to load due to directory structure mismatches. The system was looking for models in directories with full repository names but finding them in simplified directories.

## Problems Fixed

### 1. Duplicate Method Definitions
- Removed duplicate `getMLXModelDirectory` from ModelFormatValidator
- Method now only exists in ModelFileManager

### 2. Missing Directory Mappings
Added mappings for SmolLM models in multiple locations:
- ModelFileManager: Both full repo names and simplified names
- ModelFormatValidator: Full mapping table

### 3. Directory Structure
MLX models can now be found in two formats:
- Full format: `/models/mlx-community/SmolLM-135M-Instruct-4bit/`
- Simplified: `/models/mlx-community/smollm-135m/`

## Mapping Table
```swift
// Full repo name -> Model ID
"SmolLM-135M-Instruct-4bit": "smollm-135m"
"SmolLM-360M-Instruct-4bit": "smollm-360m"
"SmolLM-1.7B-Instruct-4bit": "smollm-1.7b"
"TinyLlama-1.1B-Chat-v1.0-4bit": "tinyllama-1.1b"
"Qwen2.5-0.5B-Instruct-4bit": "qwen2.5-0.5b"
"Qwen2.5-1.5B-Instruct-4bit": "qwen2.5-1.5b"
"deepseek-coder-1.3b-instruct-4bit": "deepseek-coder-1.3b"
"gemma-2b-it-4bit": "gemma-2b"
"OpenELM-1_1B-Instruct-4bit": "openelm-1.1b"
"Llama-3.2-1B-Instruct-4bit": "llama-3.2-1b"
```

## Cellular Network Note
Downloads may fail or be slow on cellular connections. The app includes NetworkMonitor that detects connection types (WiFi, Cellular, Ethernet) and can warn users about expensive or constrained connections.