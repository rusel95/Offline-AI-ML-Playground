# MLX Directory Structure Fix

## The Problem
MLX Swift expects models to be downloaded to a specific directory structure:
```
/Documents/Models/models/mlx-community/SmolLM-135M-Instruct-4bit/
├── config.json
├── model.safetensors
├── tokenizer.json
└── tokenizer_config.json
```

But our download system was saving files as:
```
/Documents/Models/smollm-135m
```

This mismatch caused the error:
> "model.safetensors...couldn't be moved to SmolLM-135M-Instruct-4bit because either the former doesn't exist, or the folder containing the latter doesn't exist"

## The Solution

Created `MLXModelDownloader` that:
1. **Uses MLX's own download system** - Let MLX handle the entire download process
2. **Preserves MLX's directory structure** - Models go to `/Models/models/{repo}/`
3. **Tracks downloads properly** - Creates marker files and updates our tracking

### Key Components

**MLXModelDownloader.swift**
- Uses `LLMModelFactory.loadContainer()` to download models
- Respects MLX's expected directory layout
- Provides progress tracking

**Updated SharedModelManager**
- Uses MLXModelDownloader for mlx-community models
- Falls back to URLSession for other models
- Tracks download progress from MLX system

**Updated ModelFileManager**
- Checks both our structure and MLX's structure
- Maps MLX repository paths to model IDs
- Handles .downloaded marker files

**Updated AIInferenceManager**
- Checks MLX directory structure for model existence
- Uses proper paths for loading

## How It Works Now

1. **Download Request**: User taps download for an MLX model
2. **MLX Downloads**: MLXModelDownloader uses MLX's system to download all files
3. **Directory Structure**: Files saved to `/Models/models/mlx-community/{model}/`
4. **Tracking**: Marker file created, ModelFileManager updated
5. **Loading**: AIInferenceManager finds model in MLX location
6. **Success**: Model loads with all required files present

## Result
✅ MLX models download with proper directory structure
✅ All required files (config.json, tokenizer, etc.) are included
✅ Models load successfully without file not found errors
✅ Progress tracking works during download