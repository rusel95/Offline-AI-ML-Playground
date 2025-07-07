//
//  ModelCardView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Model Card View
struct ModelCardView: View {
    let model: AIModel
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model header
            HStack(alignment: .top, spacing: 12) {
                // Model brand icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(model.displayColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: model.displayIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(model.displayColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.formattedSize)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(model.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(model.displayColor.opacity(0.15))
                        .foregroundColor(model.displayColor)
                        .cornerRadius(6)
                }
            }
            
            // Tags
            if !model.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // Download status and action
            ModelActionView(model: model, downloadManager: downloadManager)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview Helper
private class PreviewDownloadManager: ModelDownloadManager {
    var mockDownloadedModels: Set<String> = []
    var mockActiveDownloads: [String: ModelDownload] = [:]
    
    override init() {
        super.init()
    }
    
    override func isModelDownloaded(_ modelId: String) -> Bool {
        mockDownloadedModels.contains(modelId)
    }
    
    func setDownloaded(_ modelId: String) {
        mockDownloadedModels.insert(modelId)
    }
    
    func setDownloading(_ modelId: String, progress: Double) {
        let mockTask = URLSession.shared.downloadTask(with: URL(string: "https://example.com")!)
        let download = ModelDownload(
            modelId: modelId,
            progress: progress,
            totalBytes: 1_000_000_000,
            downloadedBytes: Int64(progress * 1_000_000_000),
            speed: 2_500_000, // 2.5 MB/s
            task: mockTask
        )
        activeDownloads[modelId] = download
    }
}

// MARK: - Previews
#Preview("Model Cards") {
    ScrollView {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 350, maximum: 400), spacing: 20)
        ], spacing: 20) {
            ForEach(AIModel.sampleModels, id: \.id) { model in
                ModelCardView(
                    model: model,
                    downloadManager: PreviewDownloadManager()
                )
            }
            
            // Show downloaded state
            ModelCardView(
                model: AIModel.sampleModels[0],
                downloadManager: {
                    let manager = PreviewDownloadManager()
                    manager.setDownloaded(AIModel.sampleModels[0].id)
                    return manager
                }()
            )
            
            // Show downloading state
            ModelCardView(
                model: AIModel.sampleModels[1],
                downloadManager: {
                    let manager = PreviewDownloadManager()
                    manager.setDownloading(AIModel.sampleModels[1].id, progress: 0.65)
                    return manager
                }()
            )
        }
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Single Card") {
    ModelCardView(
        model: AIModel.sampleModels[0],
        downloadManager: PreviewDownloadManager()
    )
    .padding()
    .background(Color.gray.opacity(0.1))
    .frame(width: 400)
} 