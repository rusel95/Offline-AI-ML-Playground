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
    let provider: Provider // Add provider property
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
    
    // MARK: - Provider Detection
    var detectedProvider: Provider {
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

// MARK: - Provider
enum Provider: String, CaseIterable {
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
    
    var displayName: String {
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
    
    var color: Color {
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
    
    var iconName: String {
        switch self {
        case .meta: return "m.circle.fill"
        case .google: return "g.circle.fill"
        case .mistral: return "wind"
        case .deepseek: return "eye.circle.fill"
        case .bigcode: return "star.circle.fill"
        case .apple: return "applelogo"
        case .huggingFace: return "face.smiling.inverse"
        case .stabilityAI: return "wand.and.stars"
        case .microsoft: return "microsoft.logo"
        case .anthropic: return "person.circle.fill"
        case .openAI: return "brain.head.profile"
        case .compVis: return "photo.artframe"
        case .xai: return "x.circle.fill"
        case .other: return "building.2"
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

// MARK: - Dynamic Model System
// All models are now discovered dynamically from Hugging Face API
// No static models - the system is fully entropic and fluid 
