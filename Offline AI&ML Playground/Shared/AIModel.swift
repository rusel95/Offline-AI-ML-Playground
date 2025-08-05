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
    public let name: String
    public let description: String
    public let huggingFaceRepo: String
    public let filename: String
    public let sizeInBytes: Int64
    public let type: ModelType
    public let tags: [String]
    public let isGated: Bool
    public let provider: Provider // Add provider property
    
    // Swift Transformers tokenizer compatibility
    public var hasSwiftTransformersSupport: Bool {
        let supportedTypes = ["gpt2", "gpt-neo", "gpt-j", "santacoder", "starcoder", "falcon", "llama", "llama2"]
        let lowercasedRepo = huggingFaceRepo.lowercased()
        
        // Check for exact matches or partial matches
        for supportedType in supportedTypes {
            if lowercasedRepo.contains(supportedType) {
                return true
            }
        }
        
        // Additional checks for specific models
        if lowercasedRepo.contains("tinyllama") ||
           lowercasedRepo.contains("dialogpt") ||
           lowercasedRepo.contains("pythia") ||
           lowercasedRepo.contains("opt-") {
            return true
        }
        
        return false
    }
    
    // Get tokenizer type description
    public var tokenizerInfo: String {
        if hasSwiftTransformersSupport {
            return "Swift Transformers + MLX"
        } else {
            return "MLX Built-in"
        }
    }
    
    // Context window size in tokens (approximate)
    public var maxContextTokens: Int {
        switch id {
        // Small models with limited context
        case "gpt2": return 1024
        case "distilbert": return 512
        case "all-minilm-l6-v2": return 512
        case "mobilevit": return 512
        
        // Medium models with standard context
        case "tinyllama-1.1b": return 2048
        case "smollm-135m": return 2048
        case "openelm-1.1b": return 2048
        case "gemma-2b": return 8192
        case "phi-2": return 2048
        case "openelm-3b": return 2048
        case "starcoder2-3b": return 4096
        
        // Larger models with extended context
        case "llama-3.2-3b": return 8192
        case "qwen2.5-3b": return 8192
        case "phi-3-mini-4k": return 4096
        case "phi-3-mini-128k": return 131072
        case "mistral-7b-instruct", "mistral-7b-openorca": return 8192
        case "llama-2-7b": return 4096
        case "deepseek-llm-7b": return 4096
        case "codellama-7b": return 16384
        case "grok-beta": return 8192
        
        // Default conservative estimate
        default: return 2048
        }
    }
    
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
        // iPhone-optimized models (smallest to largest)
        case "smollm-135m": return "0.08 - 0.12 GB"
        case "gpt2": return "0.15 - 0.25 GB"
        case "tinyllama-1.1b": return "0.7 - 0.9 GB"
        case "openelm-1.1b": return "1.1 - 1.3 GB"
        case "gemma-2b": return "1.2 - 1.5 GB"
        case "phi-2": return "2.7 - 3.2 GB"
        case "openelm-3b": return "3.0 - 3.5 GB"
        case "llama-3.2-3b": return "3.2 - 3.8 GB"
        case "qwen2.5-3b": return "3.5 - 4.0 GB"
        
        // Legacy models (for backward compatibility)
        case "phi-3-mini-4k", "phi-3-mini-128k": return "2.5 - 3 GB"
        case "llama-2-7b", "deepseek-llm-7b": return "4 - 5 GB"
        case "codellama-7b": return "4.5 - 5.5 GB"
        case "llama-3-70b": return "40 - 50 GB"
        case "mistral-7b-instruct", "mistral-7b-openorca": return "4.5 - 5.5 GB"
        case "starcoder2-3b": return "1.8 - 2.2 GB"
        case "distilbert": return "0.3 - 0.4 GB"
        case "mobilevit": return "0.06 - 0.1 GB"
        case "all-minilm-l6-v2": return "0.1 - 0.15 GB"
        case "grok-beta": return "9 - 12 GB"
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
    
    // MARK: - Enhanced Model Information
    
    /// Detailed use cases based on model type and capabilities
    public var useCases: [String] {
        switch type {
        case .llama:
            return [
                "General conversation and chat",
                "Question answering",
                "Text summarization",
                "Creative writing",
                "Language translation",
                "Instruction following"
            ]
        case .mistral:
            return [
                "Advanced reasoning tasks",
                "Complex instruction following",
                "Multi-turn conversations",
                "Creative content generation",
                "Text analysis and interpretation",
                "Educational assistance"
            ]
        case .code:
            return [
                "Code generation and completion",
                "Bug detection and fixing",
                "Code explanation and documentation",
                "Algorithm implementation",
                "Code review and optimization",
                "Programming tutorials"
            ]
        case .stable_diffusion:
            return [
                "Text-to-image generation",
                "Image editing and enhancement",
                "Artistic style transfer",
                "Concept visualization",
                "Creative design assistance",
                "Image inpainting"
            ]
        case .general:
            return [
                "General purpose AI tasks",
                "Text processing and analysis",
                "Information extraction",
                "Content moderation",
                "Research assistance",
                "Educational support"
            ]
        }
    }
    
    /// Strengths of the model
    public var strengths: [String] {
        var modelStrengths: [String] = []
        
        // Size-based strengths
        let sizeGB = Double(sizeInBytes) / 1_073_741_824.0
        if sizeGB < 1.0 {
            modelStrengths.append("Ultra-lightweight and fast")
            modelStrengths.append("Low memory usage")
        } else if sizeGB < 2.0 {
            modelStrengths.append("Lightweight and efficient")
            modelStrengths.append("Mobile-optimized")
        } else if sizeGB < 5.0 {
            modelStrengths.append("Balanced performance and size")
            modelStrengths.append("Good accuracy-to-size ratio")
        } else {
            modelStrengths.append("High-quality responses")
            modelStrengths.append("Advanced capabilities")
        }
        
        // Type-based strengths
        switch type {
        case .code:
            modelStrengths.append("Specialized for programming")
            modelStrengths.append("Multi-language support")
        case .llama:
            modelStrengths.append("Meta's proven architecture")
            modelStrengths.append("Well-documented and tested")
        case .mistral:
            modelStrengths.append("European AI excellence")
            modelStrengths.append("Instruction-tuned")
        case .stable_diffusion:
            modelStrengths.append("Creative image generation")
            modelStrengths.append("Artistic capabilities")
        case .general:
            modelStrengths.append("Versatile applications")
            modelStrengths.append("Broad knowledge base")
        }
        
        // Provider-based strengths
        switch provider {
        case .meta:
            modelStrengths.append("Open-source leader")
        case .microsoft:
            modelStrengths.append("Enterprise-grade quality")
        case .google:
            modelStrengths.append("Research-backed development")
        case .deepseek:
            modelStrengths.append("Specialized AI expertise")
        case .mistral:
            modelStrengths.append("European privacy standards")
        default:
            break
        }
        
        return Array(Set(modelStrengths)) // Remove duplicates
    }
    
    /// Performance characteristics
    public var performanceProfile: PerformanceProfile {
        let sizeGB = Double(sizeInBytes) / 1_073_741_824.0
        
        if sizeGB < 1.0 {
            return PerformanceProfile(
                speed: .fast,
                memoryUsage: .low,
                accuracy: .good,
                powerEfficiency: .excellent
            )
        } else if sizeGB < 2.0 {
            return PerformanceProfile(
                speed: .fast,
                memoryUsage: .moderate,
                accuracy: .good,
                powerEfficiency: .good
            )
        } else if sizeGB < 5.0 {
            return PerformanceProfile(
                speed: .moderate,
                memoryUsage: .moderate,
                accuracy: .excellent,
                powerEfficiency: .moderate
            )
        } else {
            return PerformanceProfile(
                speed: .slow,
                memoryUsage: .high,
                accuracy: .excellent,
                powerEfficiency: .low
            )
        }
    }
    
    /// Recommended use cases with difficulty levels
    public var recommendedTasks: [RecommendedTask] {
        switch type {
        case .code:
            return [
                RecommendedTask(title: "Code Completion", difficulty: .beginner, description: "Auto-complete code as you type"),
                RecommendedTask(title: "Bug Fixing", difficulty: .intermediate, description: "Identify and fix code issues"),
                RecommendedTask(title: "Algorithm Design", difficulty: .advanced, description: "Design complex algorithms and data structures"),
                RecommendedTask(title: "Code Review", difficulty: .intermediate, description: "Review code for best practices and improvements")
            ]
        case .llama, .mistral, .general:
            return [
                RecommendedTask(title: "Q&A Assistant", difficulty: .beginner, description: "Answer questions on various topics"),
                RecommendedTask(title: "Content Writing", difficulty: .intermediate, description: "Write articles, emails, and creative content"),
                RecommendedTask(title: "Research Helper", difficulty: .advanced, description: "Analyze complex topics and provide insights"),
                RecommendedTask(title: "Language Translation", difficulty: .intermediate, description: "Translate between different languages")
            ]
        case .stable_diffusion:
            return [
                RecommendedTask(title: "Image Generation", difficulty: .beginner, description: "Create images from text descriptions"),
                RecommendedTask(title: "Style Transfer", difficulty: .intermediate, description: "Apply artistic styles to images"),
                RecommendedTask(title: "Concept Art", difficulty: .advanced, description: "Generate concept art and illustrations"),
                RecommendedTask(title: "Logo Design", difficulty: .intermediate, description: "Create logos and brand elements")
            ]
        }
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
public struct ModelDownload: Identifiable {
    public var id: String { modelId }
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

// MARK: - Supporting Types for Enhanced Model Information

/// Performance characteristics of a model
public struct PerformanceProfile {
    public let speed: PerformanceLevel
    public let memoryUsage: PerformanceLevel
    public let accuracy: PerformanceLevel
    public let powerEfficiency: PerformanceLevel
    
    public init(speed: PerformanceLevel, memoryUsage: PerformanceLevel, accuracy: PerformanceLevel, powerEfficiency: PerformanceLevel) {
        self.speed = speed
        self.memoryUsage = memoryUsage
        self.accuracy = accuracy
        self.powerEfficiency = powerEfficiency
    }
}

/// Performance level enumeration
public enum PerformanceLevel: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case moderate = "Moderate"
    case low = "Low"
    case fast = "Fast"
    case slow = "Slow"
    case high = "High"
    
    public var color: Color {
        switch self {
        case .excellent, .fast, .good:
            return .green
        case .moderate:
            return .orange
        case .low, .slow, .high:
            return .red
        }
    }
    
    public var iconName: String {
        switch self {
        case .excellent, .fast:
            return "checkmark.circle.fill"
        case .good:
            return "checkmark.circle"
        case .moderate:
            return "minus.circle"
        case .low, .slow:
            return "xmark.circle"
        case .high:
            return "exclamationmark.circle.fill"
        }
    }
}

/// Recommended task with difficulty level
public struct RecommendedTask {
    public let title: String
    public let difficulty: TaskDifficulty
    public let description: String
    
    public init(title: String, difficulty: TaskDifficulty, description: String) {
        self.title = title
        self.difficulty = difficulty
        self.description = description
    }
}

/// Task difficulty levels
public enum TaskDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    
    public var color: Color {
        switch self {
        case .beginner:
            return .green
        case .intermediate:
            return .blue
        case .advanced:
            return .orange
        case .expert:
            return .red
        }
    }
    
    public var iconName: String {
        switch self {
        case .beginner:
            return "1.circle.fill"
        case .intermediate:
            return "2.circle.fill"
        case .advanced:
            return "3.circle.fill"
        case .expert:
            return "4.circle.fill"
        }
    }
}

// MARK: - Dynamic Model System
// All models are now discovered dynamically from Hugging Face API
// No static models - the system is fully entropic and fluid 
