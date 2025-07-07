//
//  AIModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import Foundation

// MARK: - AI Model
struct AIModel: Identifiable {
    let id: String
    let name: String
    let description: String
    let huggingFaceRepo: String
    let filename: String
    let sizeInBytes: Int64
    let type: ModelType
    let tags: [String]
    let isGated: Bool
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
    
    // MARK: - Logo Support
    var brandIcon: String? {
        // Detect brand from model name or repo and return appropriate SF Symbol
        let nameAndRepo = (name + " " + huggingFaceRepo).lowercased()
        
        if nameAndRepo.contains("llama") || nameAndRepo.contains("meta") {
            return "m.circle.fill" // Meta's M
        } else if nameAndRepo.contains("mistral") {
            return "wind" // Mistral = wind
        } else if nameAndRepo.contains("deepseek") {
            return "eye.circle.fill" // DeepSeek = deep sight
        } else if nameAndRepo.contains("starcoder") || nameAndRepo.contains("bigcode") {
            return "star.circle.fill" // StarCoder = star
        } else if nameAndRepo.contains("apple") || nameAndRepo.contains("mobilevit") {
            return "applelogo" // Apple logo
        } else if nameAndRepo.contains("distilbert") || nameAndRepo.contains("google") {
            return "g.circle.fill" // Google's G
        } else if nameAndRepo.contains("sentence-transformers") || nameAndRepo.contains("all-minilm") {
            return "face.smiling.inverse" // Hugging Face emoji
        } else if nameAndRepo.contains("stable") && nameAndRepo.contains("diffusion") {
            return "wand.and.stars" // Stability AI = magic wand
        }
        return nil
    }
    
    var brandColor: Color? {
        // Brand-specific colors
        let nameAndRepo = (name + " " + huggingFaceRepo).lowercased()
        
        if nameAndRepo.contains("llama") || nameAndRepo.contains("meta") {
            return Color.blue // Meta blue
        } else if nameAndRepo.contains("mistral") {
            return Color.orange // Mistral orange
        } else if nameAndRepo.contains("deepseek") {
            return Color.purple // DeepSeek purple
        } else if nameAndRepo.contains("starcoder") || nameAndRepo.contains("bigcode") {
            return Color.yellow // StarCoder yellow
        } else if nameAndRepo.contains("apple") || nameAndRepo.contains("mobilevit") {
            return Color.primary // Apple black/white
        } else if nameAndRepo.contains("distilbert") || nameAndRepo.contains("google") {
            return Color.red // Google red
        } else if nameAndRepo.contains("sentence-transformers") || nameAndRepo.contains("all-minilm") {
            return Color.yellow // Hugging Face yellow
        } else if nameAndRepo.contains("stable") && nameAndRepo.contains("diffusion") {
            return Color.purple // Stability purple
        }
        return nil
    }
    
    var displayIcon: String {
        return brandIcon ?? type.iconName
    }
    
    var displayColor: Color {
        return brandColor ?? type.color
    }
    
    var isUsingBrandIcon: Bool {
        return brandIcon != nil
    }
}

// MARK: - Model Type
enum ModelType: String, CaseIterable {
    case llama = "llama"
    case mistral = "mistral"
    case stable_diffusion = "stable_diffusion"
    case code = "code"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .llama: return "Llama"
        case .mistral: return "Mistral"
        case .stable_diffusion: return "Stable Diffusion"
        case .code: return "Code"
        case .general: return "General"
        }
    }
    
    var color: Color {
        switch self {
        case .llama: return .orange
        case .mistral: return .red
        case .stable_diffusion: return .pink
        case .code: return .green
        case .general: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .llama: return "brain.head.profile"
        case .mistral: return "wind"
        case .stable_diffusion: return "photo.artframe"
        case .code: return "curlybraces"
        case .general: return "cpu"
        }
    }
}

// MARK: - Model Download
struct ModelDownload {
    let modelId: String
    let progress: Double
    let totalBytes: Int64
    let downloadedBytes: Int64
    let speed: Double // bytes per second
    let task: URLSessionDownloadTask
    
    var formattedSpeed: String {
        if speed < 1024 {
            return "\(Int(speed)) B/s"
        } else if speed < 1024 * 1024 {
            return "\(Int(speed / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        }
    }
}

// MARK: - Sample Data for Previews
extension AIModel {
    static let sampleModels: [AIModel] = [
        AIModel(
            id: "llama-2-7b-chat-q4",
            name: "Llama 2 7B Chat Q4_0",
            description: "Quantized Llama 2 7B model - tested and working for chat applications",
            huggingFaceRepo: "TheBloke/Llama-2-7B-Chat-GGML",
            filename: "llama-2-7b-chat.q4_0.bin",
            sizeInBytes: 3_800_000_000, // ~3.8GB
            type: .llama,
            tags: ["chat", "ggml", "quantized", "7b"],
            isGated: false
        ),
        AIModel(
            id: "stable-diffusion-v1",
            name: "Stable Diffusion v1.4",
            description: "Text-to-image generation model",
            huggingFaceRepo: "CompVis/stable-diffusion-v1-4",
            filename: "model.ckpt",
            sizeInBytes: 4_000_000_000, // ~4GB
            type: .stable_diffusion,
            tags: ["text-to-image", "diffusion", "v1.4"],
            isGated: false
        )
    ]
    
    static let sampleModel = sampleModels[0]
} 