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
    @State private var showingDetailedInfo = false
    
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
                
                // Info button
                Button(action: {
                    showingDetailedInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            // Download status and action
            ModelActionView(model: model, downloadManager: downloadManager)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingDetailedInfo) {
            ModelDetailedInfoView(model: model)
        }
    }
}

// MARK: - Model Detailed Info View
struct ModelDetailedInfoView: View {
    let model: AIModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack(alignment: .top, spacing: 16) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(model.displayColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: model.displayIcon)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(model.displayColor)
                            )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(model.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                    }
                    
                    // Provider info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Provider")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 8) {
                            Image(systemName: model.provider.iconName)
                                .foregroundStyle(model.provider.color)
                                .font(.title3)
                            
                            Text(model.provider.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(model.provider.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Model details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            detailRow(title: "Size", value: model.formattedSize)
                            detailRow(title: "Type", value: model.type.displayName)
                            detailRow(title: "Repository", value: model.huggingFaceRepo)
                            detailRow(title: "Filename", value: model.filename)
                            detailRow(title: "Gated", value: model.isGated ? "Yes" : "No")
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
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Model Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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