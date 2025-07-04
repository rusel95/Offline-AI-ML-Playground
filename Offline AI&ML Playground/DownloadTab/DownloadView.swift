//
//  DownloadView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import Foundation

// MARK: - Main Download View
struct SimpleDownloadView: View {
    @StateObject private var downloadManager = ModelDownloadManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        // Use different layouts for different screen sizes
        if horizontalSizeClass == .regular {
            // iPad/macOS layout with sidebar
            macOSLayout
        } else {
            // iPhone layout - simple and clean
            iPhoneLayout
        }
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Active Downloads Section (prominently displayed)
                if !downloadManager.activeDownloads.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Downloading")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(downloadManager.activeDownloads.count)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.blue, in: Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        
                        ForEach(Array(downloadManager.activeDownloads.keys), id: \.self) { modelId in
                            if let download = downloadManager.activeDownloads[modelId],
                               let model = downloadManager.availableModels.first(where: { $0.id == modelId }) {
                                DownloadProgressView(model: model, download: download)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 8)
                            }
                        }
                        
                        Divider()
                            .padding(.top, 8)
                    }
                    .background(.regularMaterial)
                }
                
                // Storage Info Header (compact for iPhone)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Available Models")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(downloadManager.formattedStorageUsed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        downloadManager.refreshAvailableModels()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                
                // Models List (iPhone-optimized)
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(downloadManager.availableModels, id: \.id) { model in
                            iPhoneModelCard(model: model)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("AI Models")
            .onAppear {
                downloadManager.loadDownloadedModels()
                if downloadManager.availableModels.isEmpty {
                    downloadManager.refreshAvailableModels()
                }
            }
        }
    }
    
    // MARK: - macOS Layout
    private var macOSLayout: some View {
        NavigationSplitView {
            // Sidebar with categories and storage info
            VStack(spacing: 20) {
                StorageHeaderView(downloadManager: downloadManager)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Categories")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(ModelType.allCases, id: \.self) { type in
                        HStack {
                            Circle()
                                .fill(type.color)
                                .frame(width: 8, height: 8)
                            Text(type.displayName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(downloadManager.availableModels.filter { $0.type == type }.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 250, idealWidth: 280)
            
        } detail: {
            // Main content area
            VStack(spacing: 0) {
                // Header with title and refresh button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Models")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Download AI models for offline use")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        downloadManager.refreshAvailableModels()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider()
                
                // Models grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 400, maximum: 500), spacing: 20)
                    ], spacing: 20) {
                        ForEach(downloadManager.availableModels, id: \.id) { model in
                            ModelCardView(
                                model: model,
                                downloadManager: downloadManager
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            downloadManager.loadDownloadedModels()
            if downloadManager.availableModels.isEmpty {
                downloadManager.refreshAvailableModels()
            }
        }
    }
    
    // MARK: - iPhone Model Card
    @ViewBuilder
    private func iPhoneModelCard(model: AIModel) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Model icon and type
                ZStack {
                    Circle()
                        .fill(model.type.color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: model.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(model.type.color)
                }
                
                // Model info
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(model.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray, in: Capsule())
                        
                        Text(model.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(model.type.color, in: Capsule())
                    }
                }
                
                Spacer()
                
                // Action button
                ModelActionView(
                    model: model,
                    downloadManager: downloadManager
                )
            }
            .padding(12)
            
            // Download progress (if downloading)
            if let download = downloadManager.activeDownloads[model.id] {
                ProgressView(value: download.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Download Progress View
struct DownloadProgressView: View {
    let model: AIModel
    let download: ModelDownload
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(model.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(download.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: download.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                if let speed = formatDownloadSpeed(task: download.task) {
                    Text(speed)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("Downloading...")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
    
    private func formatDownloadSpeed(task: URLSessionDownloadTask) -> String? {
        // This is a placeholder - you'd need to implement speed calculation
        return "1.2 MB/s"
    }
}

// MARK: - Preview
#Preview("iPhone Download View") {
    SimpleDownloadView()
}

#Preview("macOS Download View") {
    SimpleDownloadView()
} 