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
struct DownloadView: View {
    @StateObject private var viewModel = DownloadViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        iPhoneLayout
    }
    
    // MARK: - iPhone Layout
    private var iPhoneLayout: some View {
        mainContentList
    }
    
    private var mainContentList: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                activeDownloadsSection
                availableModelsSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var activeDownloadsSection: some View {
        if viewModel.hasActiveDownloads {
            VStack(alignment: .leading, spacing: 16) {
                // Section header with modern styling
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    Text("Active Downloads")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding(.horizontal, 4)
                
                // Downloads list with beautiful card styling
                VStack(spacing: 12) {
                    ForEach(viewModel.activeDownloads) { download in
                        if let model = viewModel.availableModels.first(where: { $0.id == download.modelId }) {
                            DownloadProgressCard(model: model, download: download, viewModel: viewModel)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.regularMaterial)
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section header with modern styling
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundStyle(.purple)
                    .font(.title2)
                Text("Available Models")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Provider sections with improved spacing
            VStack(spacing: 24) {
                ForEach(Provider.allCases, id: \.self) { provider in
                    if !modelsForProvider(provider).isEmpty {
                        providerSection(for: provider)
                    }
                }
            }
        }
    }
    
    private func modelsForProvider(_ provider: Provider) -> [AIModel] {
        return viewModel.availableModels.filter { $0.provider == provider }
    }
    
    private func providerSection(for provider: Provider) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Provider header with elegant styling
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: provider.iconName)
                        .foregroundStyle(provider.color)
                        .font(.title2)
                        .frame(width: 28, height: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("\(modelsForProvider(provider).count) models available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(provider.color.opacity(0.1))
                )
            }
            
            // Models for this provider with card styling
            VStack(spacing: 12) {
                ForEach(modelsForProvider(provider), id: \.id) { model in
                    ModelCardView(
                        model: model,
                        viewModel: ModelCardViewModel(model: model, downloadViewModel: viewModel)
                    )
                }
            }
        }
    }
    
    
    private var sidebarStorageHeader: some View {
        StorageHeaderView(viewModel: viewModel)
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
    }
    
    private var macOSModelsGrid: some View {
        LazyVGrid(columns: macOSGridColumns, spacing: 20) {
            ForEach(viewModel.availableModels, id: \.id) { model in
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
            viewModel: ModelCardViewModel(model: model, downloadViewModel: viewModel)
        )
        .frame(maxWidth: 400, minHeight: 180)
    }
    

}

// MARK: - Preview
#Preview("iPhone Download View") {
    DownloadView()
}

#Preview("macOS Download View") {
    DownloadView()
} 
