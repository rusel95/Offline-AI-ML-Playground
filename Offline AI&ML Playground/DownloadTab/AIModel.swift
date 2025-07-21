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
public struct AIModel: Identifiable {
    public let id: String
    let name: String
    let description: String
    let huggingFaceRepo: String
    let filename: String
    let sizeInBytes: Int64
    let type: ModelType
    let tags: [String]
    let isGated: Bool
    let provider: Provider // Add provider property
    
    public var formattedSize: String {
        let gb = Double(sizeInBytes) / 1_073_741_824.0
        if gb >= 1.0 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(sizeInBytes) / 1_048_576.0
            return String(format: "%.1f MB", mb)
        }
    }
    
    public var formattedRegularMemory: String {
        switch id {
        case "phi-3-mini-4k", "phi-3-mini-128k": return "2.5 - 3 GB"
        case "phi-2": return "1.6 - 2 GB"
        case "tinyllama-1.1b": return "0.7 - 0.9 GB"
        case "llama-2-7b", "deepseek-llm-7b": return "4 - 5 GB"
        case "codellama-7b": return "4.5 - 5.5 GB"
        case "llama-3-70b": return "40 - 50 GB"
        case "mistral-7b-instruct", "mistral-7b-openorca": return "4.5 - 5.5 GB"
        case "deepseek-coder-1.3b": return "0.8 - 1 GB"
        case "starcoder2-3b": return "1.8 - 2.2 GB"
        case "distilbert": return "0.3 - 0.4 GB"
        case "mobilevit": return "0.06 - 0.1 GB"
        case "all-minilm-l6-v2": return "0.1 - 0.15 GB"
        case "grok-beta": return "9 - 12 GB"
        // Add more as needed for ~32 models, default for others
        default: 
            let gb = Double(sizeInBytes) / 1_073_741_824
            return String(format: "%.1f - %.1f GB", gb * 1.1, gb * 1.5)
        }
    }

    public var formattedMaxMemory: String {
        switch id {
        case "phi-3-mini-4k": return "4 - 6 GB"
        case "phi-3-mini-128k": return "5 - 8 GB"
        case "phi-2": return "3 - 4 GB"
        case "tinyllama-1.1b": return "1.5 - 2 GB"
        case "llama-2-7b", "deepseek-llm-7b": return "6 - 10 GB"
        case "codellama-7b": return "7 - 11 GB"
        case "llama-3-70b": return "60 - 100 GB"
        case "mistral-7b-instruct", "mistral-7b-openorca": return "7 - 12 GB"
        case "deepseek-coder-1.3b": return "1.5 - 2.5 GB"
        case "starcoder2-3b": return "3 - 5 GB"
        case "distilbert": return "0.5 - 0.8 GB"
        case "mobilevit": return "0.15 - 0.3 GB"
        case "all-minilm-l6-v2": return "0.2 - 0.4 GB"
        case "grok-beta": return "15 - 25 GB"
        // Add more, default
        default: 
            let gb = Double(sizeInBytes) / 1_073_741_824
            return String(format: "%.1f - %.1f GB", gb * 2, gb * 4)
        }
    }
    
    // MARK: - Provider Detection
    public var detectedProvider: Provider {
        let nameAndRepo = (name + " " + huggingFaceRepo).lowercased()
        
        if nameAndRepo.contains("llama") || nameAndRepo.contains("meta") {
            return .meta
        } else if nameAndRepo.contains("mistral") {
            return .mistral
        } else if nameAndRepo.contains("deepseek") {
            return .deepseek
        } else if nameAndRepo.contains("starcoder") || nameAndRepo.contains("bigcode") {
            return .bigcode
        } else if nameAndRepo.contains("apple") || nameAndRepo.contains("mobilevit") {
            return .apple
        } else if nameAndRepo.contains("distilbert") || nameAndRepo.contains("google") {
            return .google
        } else if nameAndRepo.contains("sentence-transformers") || nameAndRepo.contains("all-minilm") {
            return .huggingFace
        } else if nameAndRepo.contains("stable") && nameAndRepo.contains("diffusion") {
            return .stabilityAI
        } else if nameAndRepo.contains("microsoft") || nameAndRepo.contains("phi") {
            return .microsoft
        } else if nameAndRepo.contains("anthropic") || nameAndRepo.contains("claude") {
            return .anthropic
        } else if nameAndRepo.contains("openai") || nameAndRepo.contains("gpt") {
            return .openAI
        }
        return .other
    }
    
    // MARK: - Logo Support
    public var brandIcon: String? {
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
    
    public var brandColor: Color? {
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
    
    public var displayIcon: String {
        return brandIcon ?? type.iconName
    }
    
    public var displayColor: Color {
        return brandColor ?? type.color
    }
    
    public var isUsingBrandIcon: Bool {
        return brandIcon != nil
    }
}

// MARK: - Model Type
public enum ModelType: String, CaseIterable {
    case llama = "llama"
    case mistral = "mistral"
    case stable_diffusion = "stable_diffusion"
    case code = "code"
    case general = "general"
    
    public var displayName: String {
        switch self {
        case .llama: return "Llama"
        case .mistral: return "Mistral"
        case .stable_diffusion: return "Stable Diffusion"
        case .code: return "Code"
        case .general: return "General"
        }
    }
    
    public var color: Color {
        switch self {
        case .llama: return .orange
        case .mistral: return .red
        case .stable_diffusion: return .pink
        case .code: return .green
        case .general: return .blue
        }
    }
    
    public var iconName: String {
        switch self {
        case .llama: return "brain.head.profile"
        case .mistral: return "wind"
        case .stable_diffusion: return "photo.artframe"
        case .code: return "curlybraces"
        case .general: return "cpu"
        }
    }
}

// MARK: - Provider
public enum Provider: String, CaseIterable {
    case meta = "meta"
    case google = "google"
    case mistral = "mistral"
    case deepseek = "deepseek"
    case bigcode = "bigcode"
    case apple = "apple"
    case huggingFace = "huggingFace"
    case stabilityAI = "stabilityAI"
    case microsoft = "microsoft"
    case anthropic = "anthropic"
    case openAI = "openAI"
    case compVis = "compVis"
    case xai = "xai"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .meta: return "Meta"
        case .google: return "Google"
        case .mistral: return "Mistral AI"
        case .deepseek: return "DeepSeek"
        case .bigcode: return "BigCode"
        case .apple: return "Apple"
        case .huggingFace: return "Hugging Face"
        case .stabilityAI: return "Stability AI"
        case .microsoft: return "Microsoft"
        case .anthropic: return "Anthropic"
        case .openAI: return "OpenAI"
        case .compVis: return "CompVis"
        case .xai: return "xAI"
        case .other: return "Other"
        }
    }
    
    public var color: Color {
        switch self {
        case .meta: return .blue
        case .google: return .red
        case .mistral: return .orange
        case .deepseek: return .purple
        case .bigcode: return .yellow
        case .apple: return .primary
        case .huggingFace: return .yellow
        case .stabilityAI: return .purple
        case .microsoft: return .blue
        case .anthropic: return .orange
        case .openAI: return .green
        case .compVis: return .blue
        case .xai: return .blue
        case .other: return .gray
        }
    }
    
    public var iconName: String {
        switch self {
        case .meta: return "m.circle.fill"
        case .google: return "g.circle.fill"
        case .mistral: return "wind"
        case .deepseek: return "eye.circle.fill"
        case .bigcode: return "star.circle.fill"
        case .apple: return "applelogo"
        case .huggingFace: return "face.smiling.inverse"
        case .stabilityAI: return "wand.and.stars"
        case .microsoft: return "m.circle.fill"
        case .anthropic: return "person.circle.fill"
        case .openAI: return "brain.head.profile"
        case .compVis: return "photo.artframe"
        case .xai: return "x.circle.fill"
        case .other: return "building.2"
        }
    }
}

// MARK: - Model Download
public struct ModelDownload {
    public let modelId: String
    public let progress: Double
    public let totalBytes: Int64
    public let downloadedBytes: Int64
    public let speed: Double // bytes per second
    public let task: URLSessionDownloadTask
    
    public var formattedSpeed: String {
        if speed < 1024 {
            return "\(Int(speed)) B/s"
        } else if speed < 1024 * 1024 {
            return "\(Int(speed / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        }
    }
}

// MARK: - Dynamic Model System
// All models are now discovered dynamically from Hugging Face API
// No static models - the system is fully entropic and fluid 
