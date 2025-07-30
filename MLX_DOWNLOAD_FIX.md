# MLX Model Download Fix

## The Problem
Models are appearing to download but only getting 15-29 byte files, which are actually HTML error pages instead of the actual model files. This prevents models from loading even though they appear as "downloaded".

## Root Causes
1. **Direct file downloads don't work** - HuggingFace returns error pages for direct `/resolve/main/model.safetensors` URLs
2. **MLX models need multiple files** - Not just model.safetensors but also config.json, tokenizer files
3. **Wrong download approach** - Using single file download instead of full repository clone

## The Solution

### Option 1: Use HuggingFace Hub Python/CLI (Recommended)
```bash
# Install huggingface-hub
pip install huggingface-hub

# Download full model repository
huggingface-cli download mlx-community/SmolLM-135M-Instruct-4bit --local-dir ./models/SmolLM-135M
```

### Option 2: Use Git LFS
```bash
# Clone the repository
git clone https://huggingface.co/mlx-community/SmolLM-135M-Instruct-4bit
cd SmolLM-135M-Instruct-4bit
git lfs pull
```

### Option 3: Manual Download via Web
1. Go to https://huggingface.co/mlx-community/[model-name]
2. Click "Files and versions" tab
3. Download each file individually:
   - model.safetensors
   - config.json
   - tokenizer.json
   - tokenizer_config.json

## Implementation Fix

The app needs to:
1. **Check downloaded file sizes** - Reject files under 1KB as likely error pages
2. **Download all required files** - Not just model.safetensors
3. **Use proper HuggingFace API** - Either hub library or git clone
4. **Validate downloads** - Check file headers and sizes

## Quick Fix for Users

1. Delete all existing "downloaded" models that show small file sizes
2. Use the web interface to manually download models
3. Place files in correct directory structure:
   ```
   Documents/Models/models/mlx-community/[model-name]/
   ├── model.safetensors
   ├── config.json
   ├── tokenizer.json
   └── tokenizer_config.json
   ```

## Code Changes Needed

1. Update `SharedModelManager` download logic to check file sizes
2. Implement proper HuggingFace Hub integration
3. Add download validation before marking as complete
4. Show proper error messages for failed downloads