//
//  DownloadDebugger.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 26.07.2025.
//

import Foundation

/// Debug helper to understand download issues
@MainActor
public class DownloadDebugger {
    
    /// Test direct download of a GGUF file
    public static func testDirectDownload() async {
        print("\n" + String(repeating: "=", count: 80))
        print("🔍 DOWNLOAD DEBUGGING TEST - PUBLIC GGUF MODELS")
        print(String(repeating: "=", count: 80) + "\n")
        
        // Test with SmolLM 135M - smallest PUBLIC model that doesn't require auth
        let testURL = "https://huggingface.co/HuggingFaceTB/smollm-135M-instruct-add-basics-Q8_0-GGUF/resolve/main/smollm-135m-instruct-add-basics-q8_0.gguf"
        
        print("📋 Testing download from: \(testURL)")
        
        do {
            // Create URL request
            guard let url = URL(string: testURL) else {
                print("❌ Invalid URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            print("📡 Sending request...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            print("\n📊 Response Details:")
            if let httpResponse = response as? HTTPURLResponse {
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Headers:")
                for (key, value) in httpResponse.allHeaderFields {
                    print("     \(key): \(value)")
                }
            }
            
            print("\n📦 Downloaded Data:")
            print("   - Size: \(data.count) bytes (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
            
            // Check first 100 bytes
            let preview = data.prefix(100)
            print("   - First 100 bytes (hex):")
            print("     " + preview.map { String(format: "%02X", $0) }.joined(separator: " "))
            
            // Try to decode as string to see if it's an error message
            if let text = String(data: data, encoding: .utf8) {
                print("\n   - As text (first 500 chars):")
                print("     " + text.prefix(500))
            }
            
            // Check if it's actually GGUF
            if data.count >= 4 {
                let magic = [UInt8](data.prefix(4))
                if magic == [0x47, 0x47, 0x55, 0x46] {
                    print("\n✅ This is a valid GGUF file!")
                } else {
                    print("\n❌ This is NOT a GGUF file (magic: \(magic.map { String(format: "0x%02X", $0) }.joined(separator: " ")))")
                }
            }
            
            // Test alternate public models if this one fails
            if data.count < 1000 {
                print("\n🔄 Testing other PUBLIC models...")
                await testPublicModels()
            }
            
        } catch {
            print("❌ Download error: \(error)")
        }
        
        print("\n" + String(repeating: "=", count: 80) + "\n")
    }
    
    /// Test multiple public GGUF models
    private static func testPublicModels() async {
        print("\n📋 Testing multiple PUBLIC GGUF models...")
        
        let publicModels = [
            (name: "SmolLM 135M", url: "https://huggingface.co/HuggingFaceTB/smollm-135M-instruct-add-basics-Q8_0-GGUF/resolve/main/smollm-135m-instruct-add-basics-q8_0.gguf"),
            (name: "Qwen2.5 0.5B", url: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"),
            (name: "Phi-3 Mini", url: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf")
        ]
        
        for model in publicModels {
            print("\n🧪 Testing: \(model.name)")
            print("   URL: \(model.url)")
            
            do {
                guard let url = URL(string: model.url) else { continue }
                
                var request = URLRequest(url: url)
                request.httpMethod = "HEAD" // Just check headers first
                
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("   Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        print("   ✅ Model is accessible without authentication!")
                    } else if httpResponse.statusCode == 302 {
                        print("   ↩️ Redirect response (normal for HuggingFace)")
                    } else {
                        print("   ❌ Unexpected status code")
                    }
                }
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check HuggingFace repository structure
    public static func checkRepositoryStructure() async {
        print("\n" + String(repeating: "=", count: 80))
        print("🔍 CHECKING PUBLIC REPOSITORY STRUCTURE")
        print(String(repeating: "=", count: 80) + "\n")
        
        // Check a PUBLIC repository structure
        let repoURL = "https://huggingface.co/api/models/HuggingFaceTB/smollm-135M-instruct-add-basics-Q8_0-GGUF/tree/main"
        
        do {
            guard let url = URL(string: repoURL) else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("📁 Files in repository:")
                for file in json {
                    if let path = file["path"] as? String,
                       let size = file["size"] as? Int {
                        print("   - \(path) (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)))")
                    }
                }
            }
            
        } catch {
            print("❌ Error checking repository: \(error)")
        }
    }
}