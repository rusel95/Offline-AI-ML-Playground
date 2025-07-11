//
//  ModelPickerView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Model Picker View
struct ModelPickerView: View {
    @ObservedObject var viewModel: SimpleChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.availableModels.isEmpty {
                    // No models available state
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Models Downloaded")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Download models from the Download tab to start chatting")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            viewModel.shouldNavigateToDownloads = true
                            dismiss()
                        } label: {
                            Text("Go to Downloads")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Models list
                    List {
                        ForEach(Provider.allCases, id: \.self) { provider in
                            if !modelsForProvider(provider).isEmpty {
                                Section(header: providerHeader(for: provider)) {
                                    ForEach(modelsForProvider(provider), id: \.id) { model in
                                        ModelPickerRow(
                                            model: model,
                                            isSelected: viewModel.selectedModel?.id == model.id,
                                            onSelect: {
                                                Task {
                                                    await viewModel.selectModel(model)
                                                    dismiss()
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Model")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Helper Functions
extension ModelPickerView {
    private func modelsForProvider(_ provider: Provider) -> [AIModel] {
        return viewModel.availableModels.filter { $0.provider == provider }
    }
    
    private func providerHeader(for provider: Provider) -> some View {
        HStack {
            Image(systemName: provider.iconName)
                .foregroundStyle(provider.color)
                .font(.title3)
            
            Text(provider.displayName)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Text("\(modelsForProvider(provider).count) models")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    ModelPickerView(viewModel: SimpleChatViewModel())
} 