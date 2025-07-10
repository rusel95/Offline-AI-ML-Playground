//
//  DownloadProgressCard.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Download Progress Card
struct DownloadProgressCard: View {
    let model: AIModel
    let download: ModelDownload
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with model info
            HStack {
                Image(systemName: model.type.iconName)
                    .foregroundStyle(model.type.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(model.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    download.task.cancel()
                    downloadManager.activeDownloads.removeValue(forKey: model.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            // Progress section with enhanced visual hierarchy
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: download.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Text("\(Int(download.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                    
                    Spacer()
                    
                    Text(download.formattedSpeed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Preview
#Preview {
    let downloadManager = ModelDownloadManager()
    let mockTask = URLSession.shared.downloadTask(with: URL(string: "https://example.com")!)
    let mockDownload = ModelDownload(
        modelId: AIModel.sampleModel.id,
        progress: 0.65,
        totalBytes: 1_000_000_000,
        downloadedBytes: 650_000_000,
        speed: 2_500_000,
        task: mockTask
    )
    
    VStack(spacing: 16) {
        DownloadProgressCard(
            model: AIModel.sampleModel,
            download: mockDownload,
            downloadManager: downloadManager
        )
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        
        DownloadProgressCard(
            model: AIModel(
                id: "test-2",
                name: "Claude 3.5 Sonnet",
                description: "Advanced reasoning and analysis",
                huggingFaceRepo: "test/claude",
                filename: "claude.gguf",
                sizeInBytes: 7_000_000_000,
                parameterCount: 3_500_000_000, // 3.5B parameters
                type: .general,
                tags: ["test", "general"],
                isGated: false,
                provider: .anthropic // Added provider
            ),
            download: ModelDownload(
                modelId: "test-2",
                progress: 0.25,
                totalBytes: 7_000_000_000,
                downloadedBytes: 1_750_000_000,
                speed: 1_200_000,
                task: mockTask
            ),
            downloadManager: downloadManager
        )
        .background(.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
    .padding()
} 