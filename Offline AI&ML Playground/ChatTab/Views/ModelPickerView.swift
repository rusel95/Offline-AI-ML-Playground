//
//  ModelPickerView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Enhanced Model Picker View
struct ModelPickerView: View {
    @StateObject private var viewModel: ModelPickerViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(chatViewModel: ChatViewModel) {
        self._chatViewModel = ObservedObject(wrappedValue: chatViewModel)
        self._viewModel = StateObject(wrappedValue: ModelPickerViewModel(chatViewModel: chatViewModel))
    }
    
    // Use the view model's computed properties
    private var filteredModels: [AIModel] {
        viewModel.filteredModels
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.hasNoModels {
                    // Enhanced empty state
                    EmptyModelsView {
                        viewModel.navigateToDownloads()
                        dismiss()
                    }
                } else {
                    VStack(spacing: 0) {
                        // Search and filter controls
                        VStack(spacing: 12) {
                            // Search bar
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                
                                TextField("Search models...", text: $viewModel.searchText)
                                    .textFieldStyle(.plain)
                                
                                if !viewModel.searchText.isEmpty {
                                    Button {
                                        viewModel.searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray6))
                            )
                            
                            // Provider filter
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ProviderFilterChip(
                                        title: "All",
                                        isSelected: viewModel.selectedProvider == nil,
                                        action: { viewModel.selectedProvider = nil }
                                    )
                                    
                                    ForEach(viewModel.uniqueProviders, id: \.self) { provider in
                                        ProviderFilterChip(
                                            title: provider.displayName,
                                            isSelected: viewModel.selectedProvider == provider,
                                            action: { 
                                                viewModel.toggleProviderFilter(provider)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        
                        // Models list with optimized rendering
                        if filteredModels.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                
                                Text("No models found")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                if !viewModel.searchText.isEmpty {
                                    Button("Clear search") {
                                        viewModel.clearFilters()
                                    }
                                    .foregroundStyle(Color.accentColor)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List {
                                ForEach(viewModel.groupedModels, id: \.provider) { group in
                                    Section {
                                        ForEach(group.models, id: \.id) { model in
                                            EnhancedModelPickerRow(
                                                model: model,
                                                isSelected: viewModel.isModelSelected(model),
                                                onSelect: {
                                                    HapticFeedback.selectionChanged()
                                                    Task {
                                                        dismiss()
                                                        await viewModel.selectModel(model)
                                                    }
                                                }
                                            )
                                        }
                                    } header: {
                                        EnhancedProviderHeader(for: group.provider, modelCount: group.models.count)
                                    }
                                }
                            }
                            .listStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// Helper functions are now handled by the view model

// MARK: - Provider Filter Chip
struct ProviderFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Enhanced Provider Header
struct EnhancedProviderHeader: View {
    let provider: Provider
    let modelCount: Int
    
    init(for provider: Provider, modelCount: Int) {
        self.provider = provider
        self.modelCount = modelCount
    }
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: provider.iconName)
                    .foregroundStyle(provider.color)
                    .font(.title3)
                    .frame(width: 20)
                
                Text(provider.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Text("\(modelCount)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(provider.color)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Enhanced Model Picker Row
struct EnhancedModelPickerRow: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Model icon with provider styling
                Image(systemName: model.displayIcon)
                    .font(.title2)
                    .foregroundStyle(model.displayColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(model.displayColor.opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                                .font(.title3)
                        }
                    }
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        // Model type badge
                        Text(model.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(model.type.color.opacity(0.2))
                            )
                            .foregroundStyle(model.type.color)
                        
                        Spacer()
                        
                        // Size info
                        Text(model.formattedSize)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }
}

// MARK: - Empty Models View
struct EmptyModelsView: View {
    let onNavigateToDownloads: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "externaldrive.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .orange.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 12) {
                Text("No Models Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Download language models from the Download tab to start chatting with AI")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                HapticFeedback.selectionChanged()
                onNavigateToDownloads()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                    Text("Go to Downloads")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview
#Preview {
    ModelPickerView(chatViewModel: ChatViewModel())
} 
