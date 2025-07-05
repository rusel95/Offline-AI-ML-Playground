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
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Models Downloaded")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Download models from the Download tab to start chatting")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Go to Downloads")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    // Models list
                    List {
                        ForEach(viewModel.availableModels, id: \.id) { model in
                            ModelPickerRow(
                                model: model,
                                isSelected: viewModel.selectedModel?.id == model.id,
                                onSelect: {
                                    viewModel.selectModel(model)
                                }
                            )
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

// MARK: - Preview
#Preview {
    ModelPickerView(viewModel: SimpleChatViewModel())
} 