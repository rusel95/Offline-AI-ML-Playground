# Active Context

**Date:** 2025-07-21
**Tags:** active, current, focus

## Current Work Focus

- **Task:** Fixing critical download/chat bugs discovered through user testing
- **Status:** In progress. Multiple critical issues identified that break the core offline-first functionality.

## Critical Issues Identified

1. **Fake Downloads:** Static model lists cause instant "downloads" that aren't real
2. **Model Mismatches:** Selected models don't match loaded configurations  
3. **Network Usage in Chat:** Chat tab downloads from internet despite showing models as local
4. **Path Inconsistencies:** Mixed usage of Models vs MLXModels directories

## Recent Changes

- Diagnosed critical bugs through user log analysis
- Identified root cause: static model definitions instead of real downloads
- Found model configuration mapping issues in AIInferenceManager

## Next Steps

1. **Fix Static Model Downloads:**
   - Remove hardcoded model lists from SharedModelManager
   - Implement real HuggingFace API model checking
   - Ensure actual file downloads with progress tracking

2. **Fix Model Configuration Mapping:**
   - Map downloaded model files to correct inference configurations
   - Ensure selected model matches loaded model

3. **Ensure Offline-First Chat:**
   - Remove all network requests from chat tab
   - Load models purely from local downloaded files
   - Verify no unexpected network usage

4. **Test End-to-End Workflow:**
   - Download model → verify local storage → chat works offline
   - Monitor network traffic to ensure no unexpected downloads
