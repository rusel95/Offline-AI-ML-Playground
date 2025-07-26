//
//  TestPublicGGUF.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 26.07.2025.
//

import Foundation

/// Test downloading and loading PUBLIC GGUF models
@MainActor
public class TestPublicGGUF {
    
    /// Test download and load of SmolLM 135M GGUF
    public static func testSmolLMDownload() async {
        print("\n" + String(repeating: "🚀", count: 40))
        print("TESTING PUBLIC GGUF MODEL: SmolLM 135M")
        print(String(repeating: "🚀", count: 40) + "\n")
        
        let sharedManager = SharedModelManager.shared
        
        // Find SmolLM model
        guard let smollm = sharedManager.availableModels.first(where: { $0.id == "smollm-135m-gguf" }) else {
            print("❌ SmolLM model not found in catalog")
            return
        }
        
        print("📋 Model Details:")
        print("   Name: \(smollm.name)")
        print("   Size: \(ByteCountFormatter.string(fromByteCount: smollm.sizeInBytes, countStyle: .file))")
        print("   Repository: \(smollm.huggingFaceRepo)")
        print("   Filename: \(smollm.filename)")
        
        // Check if already downloaded
        if sharedManager.isModelDownloaded(smollm.id) {
            print("\n✅ Model already downloaded! Testing load...")
            await testModelLoad(modelId: smollm.id)
            return
        }
        
        // Download the model
        print("\n⬇️ Starting download...")
        do {
            try await sharedManager.downloadModel(smollm)
            
            // Wait for download to complete
            var attempts = 0
            while sharedManager.activeDownloads[smollm.id] != nil && attempts < 60 {
                if let download = sharedManager.activeDownloads[smollm.id] {
                    let progress = Int(download.progress * 100)
                    let speed = ByteCountFormatter.string(fromByteCount: Int64(download.speed), countStyle: .file)
                    print("   Progress: \(progress)% - Speed: \(speed)/s", terminator: "\r")
                    fflush(stdout)
                }
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                attempts += 1
            }
            
            print("\n")
            
            // Check if download completed
            if sharedManager.isModelDownloaded(smollm.id) {
                print("✅ Download completed successfully!")
                
                // Verify the file
                if let path = sharedManager.getLocalModelPath(modelId: smollm.id) {
                    await verifyGGUFFile(at: path)
                }
                
                // Test loading
                await testModelLoad(modelId: smollm.id)
            } else {
                print("❌ Download did not complete within timeout")
            }
            
        } catch {
            print("❌ Download error: \(error)")
        }
    }
    
    /// Verify GGUF file format
    private static func verifyGGUFFile(at url: URL) async {
        print("\n🔍 Verifying GGUF file...")
        
        do {
            let fileHandle = try FileHandle(forReadingFrom: url)
            let headerData = fileHandle.readData(ofLength: 4)
            fileHandle.closeFile()
            
            let magic = [UInt8](headerData)
            print("   Magic bytes: \(magic.map { String(format: "0x%02X", $0) }.joined(separator: " "))")
            
            if magic == [0x47, 0x47, 0x55, 0x46] {
                print("   ✅ Valid GGUF file!")
                
                // Get file size
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes[.size] as? Int64 {
                    print("   File size: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                }
            } else {
                print("   ❌ Not a valid GGUF file")
            }
        } catch {
            print("   ❌ Error verifying file: \(error)")
        }
    }
    
    /// Test loading the model with MLX
    private static func testModelLoad(modelId: String) async {
        print("\n🧪 Testing MLX loading of GGUF model...")
        
        let inferenceManager = AIInferenceManager()
        
        do {
            print("   Finding model in catalog...")
            guard let model = SharedModelManager.shared.availableModels.first(where: { $0.id == modelId }) else {
                print("   ❌ Model not found in catalog")
                return
            }
            
            print("   Loading model: \(model.name)")
            try await inferenceManager.loadModel(model)
            print("   ✅ Model loaded successfully!")
            
            // Try a simple generation
            print("\n📝 Testing generation...")
            let testPrompt = "Hello, I am"
            
            let generatedText = try await inferenceManager.generateText(
                prompt: testPrompt,
                maxTokens: 10,
                temperature: 0.7
            )
            
            print("   ✅ Generation completed: \"\(generatedText)\"")
            
        } catch {
            print("   ❌ MLX loading error: \(error)")
            print("\n📊 Error Details:")
            print("   Type: \(type(of: error))")
            print("   Description: \(error.localizedDescription)")
            
            // This is where we expect to see the MLX error about GGUF
        }
    }
}