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
    
    var body: some View {
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
}

// MARK: - Preview
#Preview("Download View") {
    SimpleDownloadView()
} 