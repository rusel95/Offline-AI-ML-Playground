#!/bin/bash

# SwiftLint Build Phase Script
# This script should be added to your Xcode project as a Build Phase

# Check if SwiftLint is installed
if which swiftlint >/dev/null; then
    swiftlint
else
    echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
    
    # Try to use mint if available
    if which mint >/dev/null; then
        echo "Attempting to run SwiftLint via Mint..."
        mint run realm/SwiftLint swiftlint
    fi
fi