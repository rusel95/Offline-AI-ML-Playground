# Model Download and Loading Architecture

## Overview
This document explains how different model formats are handled in the Offline AI & ML Playground app, from detection through download to loading into memory.

## Model Format Detection Flow

```
User Selects Model
        │
        ▼
┌─────────────────────┐
│  Format Detection   │
│ (ModelFormatDetector)│
└─────────────────────┘
        │
        ├──► Contains "mlx-community"? ──► MLX Format
        │
        ├──► Filename ends with ".gguf"? ──► GGUF Format
        │
        ├──► Model size > 5GB? ──► Multi-Part Format
        │
        └──► Default ──► Single Safetensors
```

## Download Flow by Format

### 1. MLX Format Download
```
MLX Model Selected
        │
        ▼
┌─────────────────────┐
│ MLXModelDownloader  │
└─────────────────────┘
        │
        ▼
Download Files:
├── model.safetensors (required)
├── config.json (required)
├── tokenizer.json (optional)
├── tokenizer_config.json (optional)
└── special_tokens_map.json (optional)
        │
        ▼
Save to: /Documents/Models/models/mlx-community/{repo-name}/
```

### 2. Multi-Part Model Download
```
Large Model Selected (>5GB)
        │
        ▼
┌──────────────────────────┐
│ UniversalModelDownloader │
└──────────────────────────┘
        │
        ▼
1. Download model.safetensors.index.json
        │
        ▼
2. Parse index to find parts
        │
        ▼
3. Download all parts:
   ├── model-00001-of-00003.safetensors
   ├── model-00002-of-00003.safetensors
   ├── model-00003-of-00003.safetensors
   ├── config.json
   ├── tokenizer.json
   └── generation_config.json
        │
        ▼
Save to: /Documents/Models/models/{model-id}/
```

### 3. GGUF Format Download
```
GGUF Model Selected
        │
        ▼
┌──────────────────────────┐
│ UniversalModelDownloader │
└──────────────────────────┘
        │
        ▼
Download Files:
├── {model-name}.Q4_K_S.gguf (self-contained)
└── config.json (optional)
        │
        ▼
Save to: /Documents/Models/models/{model-id}/
```

## Model Loading Flow

```
Load Model Request
        │
        ▼
┌─────────────────────┐
│ AIInferenceManager  │
└─────────────────────┘
        │
        ▼
Check Model Format
        │
        ├──► MLX Format ──┐
        │                 │
        ├──► Multi-Part ──┤
        │                 │
        └──► GGUF ────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │ Memory Preparation  │
                │ - Unload current    │
                │ - Clean memory      │
                │ - Wait for cleanup  │
                └─────────────────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │  Load with MLX      │
                │  Swift Framework    │
                └─────────────────────┘
                          │
                          ▼
                ┌─────────────────────┐
                │ Model Configuration │
                │ - Set tokenizer     │
                │ - Configure params  │
                │ - Initialize LLM    │
                └─────────────────────┘
                          │
                          ▼
                    Model Ready
```

## Directory Structure

```
Documents/Models/
├── models/
│   ├── mlx-community/
│   │   ├── SmolLM-135M-Instruct-4bit/
│   │   │   ├── model.safetensors
│   │   │   ├── config.json
│   │   │   └── tokenizer.json
│   │   └── TinyLlama-1.1B-Chat-v1.0-4bit/
│   │       └── [model files]
│   │
│   ├── large-model-7b/
│   │   ├── model-00001-of-00003.safetensors
│   │   ├── model-00002-of-00003.safetensors
│   │   ├── model-00003-of-00003.safetensors
│   │   ├── model.safetensors.index.json
│   │   └── config.json
│   │
│   └── llama-2-7b-chat/
│       ├── llama-2-7b-chat.Q4_K_S.gguf
│       └── config.json
│
└── [model-id] (marker files)
```

## Key Components

### ModelFormatDetector
- Analyzes repository and file structure
- Determines optimal download strategy
- Validates downloaded files

### MLXModelDownloader
- Specialized for MLX community models
- Downloads all required MLX files
- Creates proper directory structure

### UniversalModelDownloader
- Handles multi-part and GGUF models
- Manages sequential file downloads
- Supports resume on failure

### AIInferenceManager
- Detects model format before loading
- Manages memory cleanup between models
- Configures MLX Swift for each format

## Memory Management Flow

```
1. Detect current memory usage
        │
        ▼
2. If model loaded: Unload current model
        │
        ▼
3. Perform deep memory cleanup (3 rounds)
        │
        ▼
4. Wait for memory to stabilize
        │
        ▼
5. Load new model configuration
        │
        ▼
6. Initialize MLX model container
        │
        ▼
7. Monitor memory pressure
```

## Error Handling

Each stage includes error handling:
- Network errors → Resume capability
- Format errors → Fallback detection
- Memory errors → Cleanup and retry
- File errors → Validation and re-download