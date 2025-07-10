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
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model header with minimal info
            HStack(alignment: .center, spacing: 12) {
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
                    
                    Text(model.formattedSize)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Expand/Collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
                .buttonStyle(.plain)
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    // Model description and use cases
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About This Model")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(model.richDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Use cases
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Best For")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(model.useCases, id: \.self) { useCase in
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text(useCase)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    
                    // Model details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technical Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 6) {
                            detailRow(title: "Parameters", value: model.formattedParameterCount)
                            detailRow(title: "Type", value: model.type.displayName)
                            detailRow(title: "Provider", value: model.provider.displayName)
                            detailRow(title: "Repository", value: model.huggingFaceRepo)
                        }
                    }
                    
                    // Tags
                    if !model.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(model.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.quaternary)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Download status and action
            ModelActionView(model: model, downloadManager: downloadManager)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

// MARK: - Preview Helper
struct PreviewDownloadManager: ModelDownloadManager {
    private var _downloadedModels: Set<String> = []
    private var _activeDownloads: [String: ModelDownload] = [:]
    
    override var downloadedModels: Set<String> {
        get { _downloadedModels }
        set { _downloadedModels = newValue }
    }
    
    override var activeDownloads: [String: ModelDownload] {
        get { _activeDownloads }
        set { _activeDownloads = newValue }
    }
    
    func setDownloaded(_ modelId: String) {
        _downloadedModels.insert(modelId)
    }
    
    func setDownloading(_ modelId: String, progress: Double) {
        let mockDownload = ModelDownload(
            modelId: modelId,
            progress: progress,
            totalBytes: 1_000_000_000,
            downloadedBytes: Int64(progress * 1_000_000_000),
            speed: 1_000_000,
            task: URLSession.shared.downloadTask(with: URL(string: "https://example.com")!)
        )
        _activeDownloads[modelId] = mockDownload
    }
}

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