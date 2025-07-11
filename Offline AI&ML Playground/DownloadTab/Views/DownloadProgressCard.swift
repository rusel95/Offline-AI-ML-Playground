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
