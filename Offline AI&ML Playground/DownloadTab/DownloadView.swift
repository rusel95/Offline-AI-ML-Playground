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
        mainContentList
    }
    
    private var mainContentList: some View {
        List {
            storageSection
            activeDownloadsSection
            availableModelsSection
        }
        .listStyle(.plain)
        .listRowSeparator(.hidden) // Hide all row separators
        .onAppear {
            downloadManager.refreshAvailableModels()
        }
        .refreshable {
            downloadManager.refreshAvailableModels()
        }
    }
    
    private var storageSection: some View {
        Section {
            StorageHeaderView(downloadManager: downloadManager)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)
        } header: {
            Text("Storage")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    @ViewBuilder
    private var activeDownloadsSection: some View {
        if !downloadManager.activeDownloads.isEmpty {
            Section {
                activeDownloadsList
            } header: {
                Text("Downloading")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var activeDownloadsList: some View {
        VStack(spacing: 8) {
            ForEach(Array(downloadManager.activeDownloads.values), id: \.modelId) { download in
                if let model = downloadManager.availableModels.first(where: { $0.id == download.modelId }) {
                    activeDownloadRow(model: model, download: download)
                        .padding(.horizontal, 8)
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    private func activeDownloadRow(model: AIModel, download: ModelDownload) -> some View {
        DownloadProgressCard(model: model, download: download, downloadManager: downloadManager)
            .listRowInsets(EdgeInsets())
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.05))
            )
    }
    
    private var availableModelsSection: some View {
        Section {
            availableModelsList
        } header: {
            Text("Available Models")
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
    
    private var availableModelsList: some View {
        VStack(spacing: 16) {
            ForEach(Provider.allCases, id: \.self) { provider in
                if !modelsForProvider(provider).isEmpty {
                    providerSection(for: provider)
                }
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
    
    private func modelsForProvider(_ provider: Provider) -> [AIModel] {
        return downloadManager.availableModels.filter { $0.provider == provider }
    }
    
    private func providerSection(for provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Provider header
            HStack {
                Image(systemName: provider.iconName)
                    .foregroundStyle(provider.color)
                    .font(.title3)
                
                Text(provider.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Remove the model count badge
                // Text("\(modelsForProvider(provider).count) models")
                //     .font(.caption)
                //     .foregroundStyle(.secondary)
                //     .padding(.horizontal, 8)
                //     .padding(.vertical, 4)
                //     .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 8)
            
            // Models for this provider
            VStack(spacing: 8) {
                ForEach(modelsForProvider(provider), id: \.id) { model in
                    availableModelRow(model: model)
                        .padding(.horizontal, 8)
                }
            }
        }
    }
    
    private func availableModelRow(model: AIModel) -> some View {
        ModelCardView(
            model: model,
            downloadManager: downloadManager
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
    }
    
    // MARK: - macOS Layout
    private var macOSLayout: some View {
        NavigationSplitView {
            macOSSidebar
        } detail: {
            macOSDetailView
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private var macOSSidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            sidebarStorageHeader
            modelCategoriesSection
            Spacer()
        }
        .padding(.vertical, 20)
        .frame(minWidth: 250, idealWidth: 300)
        .background(.thickMaterial)
    }
    
    private var sidebarStorageHeader: some View {
        StorageHeaderView(downloadManager: downloadManager)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var modelCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Providers")
                .font(.headline)
                .foregroundStyle(.primary)
            
            modelCategoriesList
        }
        .padding(.horizontal, 20)
    }
    
    private var modelCategoriesList: some View {
        ForEach(Provider.allCases, id: \.self) { provider in
            if !modelsForProvider(provider).isEmpty {
                modelCategoryRow(for: provider)
            }
        }
    }
    
    private func modelCategoryRow(for provider: Provider) -> some View {
        HStack {
            Image(systemName: provider.iconName)
                .foregroundStyle(provider.color)
                .frame(width: 20, height: 20)
            
            Text(provider.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            // Remove the model count badge
            // modelCountBadge(for: provider)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    
    // Remove the modelCountBadge function entirely
    // private func modelCountBadge(for provider: Provider) -> some View {
    //     Text("\(modelsForProvider(provider).count)")
    //         .font(.caption)
    //         .foregroundStyle(.secondary)
    //         .padding(.horizontal, 8)
    //         .padding(.vertical, 4)
    //         .background(.quaternary, in: Capsule())
    // }
    
    private var macOSDetailView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MLX Test Button
                Button("🧪 Run MLX Tests") {
                    Task {
                        print("🚀 Running MLX Tests from UI")
                        TestMLXFunctionality.runAllTests()
                    }
                }
                .padding()
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                .cornerRadius(8)
                
                macOSModelsGrid
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .navigationTitle("AI Models")
        .onAppear {
            downloadManager.refreshAvailableModels()
        }
    }
    
    private var macOSModelsGrid: some View {
        LazyVGrid(columns: macOSGridColumns, spacing: 20) {
            ForEach(downloadManager.availableModels, id: \.id) { model in
                macOSModelCard(for: model)
            }
        }
        .padding(20)
    }
    
    private var macOSGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
        ]
    }
    
    private func macOSModelCard(for model: AIModel) -> some View {
        ModelCardView(
            model: model,
            downloadManager: downloadManager
        )
        .frame(maxWidth: 400, minHeight: 180)
    }
    

}

// MARK: - Preview
#Preview("iPhone Download View") {
    SimpleDownloadView()
}

#Preview("macOS Download View") {
    SimpleDownloadView()
} 
