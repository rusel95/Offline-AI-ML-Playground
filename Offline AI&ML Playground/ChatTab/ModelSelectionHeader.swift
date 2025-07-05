//
//  ModelSelectionHeader.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Model Selection Header
struct ModelSelectionHeader: View {
    @ObservedObject var viewModel: SimpleChatViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Model info
            HStack(spacing: 8) {
                // Model type icon
                if let model = viewModel.selectedModel {
                    ZStack {
                        Circle()
                            .fill(model.type.color.opacity(0.1))
                            .frame(width: 32, height: 32)
                        Image(systemName: model.type.iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(model.type.color)
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Active Model")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.modelDisplayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Model switch button
            Button {
                viewModel.showingModelPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text("Switch")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
            .disabled(viewModel.availableModels.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Preview
#Preview {
    ModelSelectionHeader(viewModel: SimpleChatViewModel())
        .padding()
        .background(Color.gray.opacity(0.1))
} 