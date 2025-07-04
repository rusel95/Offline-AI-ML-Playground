//
//  ModelActionView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Model Action View
struct ModelActionView: View {
    let model: AIModel
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        if let download = downloadManager.activeDownloads[model.id] {
            // Currently downloading
            VStack(spacing: 12) {
                HStack {
                    Text("Downloading...")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("\(Int(download.progress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                ProgressView(value: download.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                HStack {
                    Text(download.formattedSpeed)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        downloadManager.cancelDownload(model.id)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }
        } else if downloadManager.isModelDownloaded(model.id) {
            // Already downloaded
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                Text("Downloaded")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                
                Spacer()
                
                Button("Delete") {
                    downloadManager.deleteModel(model.id)
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        } else {
            // Available for download
            Button(action: {
                downloadManager.downloadModel(model)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title3)
                    Text("Download")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview Helpers
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
#Preview("Download States") {
    VStack(spacing: 20) {
        Group {
            // Available for download
            ModelActionView(
                model: AIModel.sampleModel,
                downloadManager: PreviewDownloadManager()
            )
            .overlay(alignment: .trailing) {
                Text("Available")
                    .font(.caption2)
                    .padding(4)
                    .background(.gray.opacity(0.2))
                    .cornerRadius(4)
                    .offset(x: 8, y: -8)
            }
            
            // Currently downloading
            ModelActionView(
                model: AIModel.sampleModel,
                downloadManager: {
                    let manager = PreviewDownloadManager()
                    manager.setDownloading(AIModel.sampleModel.id, progress: 0.35)
                    return manager
                }()
            )
            .overlay(alignment: .trailing) {
                Text("Downloading")
                    .font(.caption2)
                    .padding(4)
                    .background(.blue.opacity(0.2))
                    .cornerRadius(4)
                    .offset(x: 8, y: -8)
            }
            
            // Already downloaded
            ModelActionView(
                model: AIModel.sampleModel,
                downloadManager: {
                    let manager = PreviewDownloadManager()
                    manager.setDownloaded(AIModel.sampleModel.id)
                    return manager
                }()
            )
            .overlay(alignment: .trailing) {
                Text("Downloaded")
                    .font(.caption2)
                    .padding(4)
                    .background(.green.opacity(0.2))
                    .cornerRadius(4)
                    .offset(x: 8, y: -8)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    .padding()
    .background(Color.gray.opacity(0.1))
} 