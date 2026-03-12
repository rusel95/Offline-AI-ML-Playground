# Swift Transformers Integration Setup

## Overview
We have implemented a new inference backend using `huggingface/swift-transformers` to provide a robust, "transformers-like" API for on-device inference, specifically targeting Core ML models.

## Implementation Details
- **Protocol**: `AIInferenceService` unifies `AIInferenceManager` (MLX) and `TransformersInferenceManager`.
- **Manager**: `TransformersInferenceManager` handles the `swift-transformers` logic.
- **UI**: Added an "Inference Engine" selector in the Chat tab settings menu.

## Required Action: Add Dependency

To enable the Transformers backend, you must add the `swift-transformers` package to your project.

1.  Open `Offline AI&ML Playground.xcodeproj` in Xcode.
2.  Go to **File > Add Package Dependencies...**.
3.  Enter the URL: `https://github.com/huggingface/swift-transformers`.
4.  Click **Add Package**.
5.  Ensure the `Transformers` library is added to the `Offline AI&ML Playground` target.

## Usage
1.  Run the app.
2.  Go to the **Chat** tab.
3.  Tap the **Settings** (ellipsis) button in the top right.
4.  Select **Inference Engine > Transformers (CoreML)**.
5.  Select a compatible model (Core ML format).
    - *Note*: The current downloader fetches `.safetensors` (MLX) and `.gguf`. You may need to manually add Core ML models or update the downloader to fetch `.mlpackage` models from Hugging Face.
    - Recommended models for testing: `apple/OpenELM-270M-Instruct` (if available in Core ML) or other Core ML converted models.

## Code Locations
- `Shared/Core/Inference/AIInferenceService.swift`: The unified protocol.
- `Shared/Core/Inference/TransformersInferenceManager.swift`: The new backend implementation.
- `ChatTab/ViewModels/ChatViewModel.swift`: Logic for switching backends.
