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
}

// MARK: - Model Type
enum ModelType: String, CaseIterable {
    case llama = "llama"
    case mistral = "mistral"
    case whisper = "whisper"
    case stable_diffusion = "stable_diffusion"
    case code = "code"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .llama: return "Llama"
        case .mistral: return "Mistral"
        case .whisper: return "Whisper"
        case .stable_diffusion: return "Stable Diffusion"
        case .code: return "Code"
        case .general: return "General"
        }
    }
    
    var color: Color {
        switch self {
        case .llama: return .orange
        case .mistral: return .red
        case .whisper: return .purple
        case .stable_diffusion: return .pink
        case .code: return .green
        case .general: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .llama: return "brain.head.profile"
        case .mistral: return "wind"
        case .whisper: return "waveform"
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
            id: "whisper-tiny",
            name: "Whisper Tiny",
            description: "Tiny Whisper model for speech recognition",
            huggingFaceRepo: "ggerganov/whisper.cpp",
            filename: "ggml-tiny.bin",
            sizeInBytes: 39_000_000, // ~39MB
            type: .whisper,
            tags: ["speech-to-text", "ggml", "tiny"],
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