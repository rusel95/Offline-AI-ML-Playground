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
    @ObservedObject var sharedManager: SharedModelManager
    
    var body: some View {
        if let download = sharedManager.activeDownloads[model.id] {
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
                        sharedManager.cancelDownload(model.id)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }
        } else if sharedManager.isModelDownloaded(model.id) {
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
                    sharedManager.deleteModel(model.id)
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        } else {
            // Available for download
            Button(action: {
                sharedManager.downloadModel(model)
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
