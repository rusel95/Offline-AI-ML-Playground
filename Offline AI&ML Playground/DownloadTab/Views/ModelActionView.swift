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
    @ObservedObject var viewModel: ModelCardViewModel
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        if viewModel.isDownloading, let download = viewModel.downloadViewModel.getDownloadProgress(for: model.id) {
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
                        viewModel.cancelDownload()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .buttonStyle(.plain)
                }
            }
        } else if viewModel.isDownloaded {
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
                    viewModel.deleteModel()
                }
                .font(.subheadline)
                .foregroundColor(.red)
                .buttonStyle(.plain)
            }
        } else {
            // Available for download
            VStack(spacing: 8) {
                Button(action: {
                    viewModel.downloadModel()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: networkMonitor.isConnected ? "arrow.down.circle.fill" : "wifi.slash")
                            .font(.title3)
                        Text(networkMonitor.isConnected ? "Download" : "No Connection")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(networkMonitor.isConnected ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(!networkMonitor.isConnected)
                
                if !networkMonitor.isConnected {
                    Text("Internet connection required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#if DEBUG
// MARK: - Preview Helpers (DEBUG only)
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
        // Do not use network in previews; create a placeholder task without hitting the network
        let download = ModelDownload(
            modelId: modelId,
            progress: progress,
            totalBytes: 1_000_000_000,
            downloadedBytes: Int64(progress * 1_000_000_000),
            speed: 2_500_000,
            task: nil
        )
        activeDownloads[modelId] = download
    }
}
#endif
