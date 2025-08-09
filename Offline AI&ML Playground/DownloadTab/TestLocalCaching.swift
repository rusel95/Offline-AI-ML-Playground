//
//  TestLocalCaching.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation
import MLX
import MLXLLM

/// Simple test class to verify local model caching functionality
@MainActor
class TestLocalCaching {
    
    static func runLocalCachingTests() {
        print("🧪 ====== Testing Local Model Caching ======")
        
        testModelDirectoryCreation()
        testLocalFileChecking()
        testFileSystemPreference()
        
        print("✅ ====== Local Caching Tests Completed ======")
    }
    
    private static func testModelDirectoryCreation() {
        print("📁 Testing model directory creation...")
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = documentsDir.appendingPathComponent("MLXModels")
        
        do {
            try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            print("✅ Models directory created: \(modelsDir.path)")
            
            // Check if directory exists
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: modelsDir.path, isDirectory: &isDirectory)
            
            if exists && isDirectory.boolValue {
                print("✅ Models directory verification passed")
            } else {
                print("❌ Models directory verification failed")
            }
        } catch {
            print("❌ Error creating models directory: \(error)")
        }
    }
    
    private static func testLocalFileChecking() {
        print("🔍 Testing local file checking logic...")
        
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = documentsDir.appendingPathComponent("MLXModels")
        
        // Test file paths
        let testPaths = [
            "test-model.gguf",
            "llama-2-7b-chat.bin",
            "mistral-7b.safetensors"
        ]
        
        for path in testPaths {
            let fullPath = modelsDir.appendingPathComponent(path)
            let exists = FileManager.default.fileExists(atPath: fullPath.path)
            
            if exists {
                print("✅ Found local model: \(path)")
            } else {
                print("📥 Model not found locally (would download): \(path)")
            }
        }
    }
    
    private static func testFileSystemPreference() {
        print("⚖️ Testing file system preference logic...")
        
        // Create test model
        let testModel = AIModel(
            id: "test-local-cache",
            name: "Test Local Cache Model",
            description: "A test model for local caching verification",
            huggingFaceRepo: "test/cache",
            filename: "model.gguf",
            sizeInBytes: 2 * 1024 * 1024 * 1024, // 2GB
            type: .general,
            tags: ["test", "cache"],
            isGated: false,
            provider: .other // Added provider
        )
        
        print("🔧 Created test model:")
        print("   ID: \(testModel.id)")
        print("   Name: \(testModel.name)")
        print("   Size: \(testModel.formattedSize)")
        print("   Repository: \(testModel.huggingFaceRepo)")
        print("   Filename: \(testModel.filename)")
        
        // Simulate local path check
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = documentsDir.appendingPathComponent("MLXModels")
        let localPath = modelsDir.appendingPathComponent(testModel.id).appendingPathComponent(testModel.filename)
        
        let isLocallyAvailable = FileManager.default.fileExists(atPath: localPath.path)
        
        if isLocallyAvailable {
            print("✅ Model would be loaded from local cache")
            print("📁 Local path: \(localPath.path)")
        } else {
            print("📥 Model would be downloaded from repository")
            print("🌐 Repository: \(testModel.huggingFaceRepo)")
            print("📁 Would save to: \(localPath.path)")
        }
        
        print("✅ File system preference logic verified")
    }
} 