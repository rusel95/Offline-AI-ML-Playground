//
//  StorageHeaderView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Storage Header View
struct StorageHeaderView: View {
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Storage")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(downloadManager.formattedStorageUsed)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            ProgressView(value: downloadManager.storageUsed, total: downloadManager.totalStorage)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview Helper
private class PreviewDownloadManager: ModelDownloadManager {
    override init() {
        super.init()
        // Set some sample data for preview
        self.storageUsed = 15_000_000_000 // 15GB used
        self.totalStorage = 100_000_000_000 // 100GB total
    }
}

// MARK: - Preview
#Preview("Storage Header") {
    VStack(spacing: 20) {
        StorageHeaderView(downloadManager: PreviewDownloadManager())
        
        // Show different states
        Group {
            StorageHeaderView(downloadManager: {
                let manager = PreviewDownloadManager()
                manager.storageUsed = 5_000_000_000 // 5GB
                return manager
            }())
            
            StorageHeaderView(downloadManager: {
                let manager = PreviewDownloadManager()
                manager.storageUsed = 80_000_000_000 // 80GB (nearly full)
                return manager
            }())
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
} 