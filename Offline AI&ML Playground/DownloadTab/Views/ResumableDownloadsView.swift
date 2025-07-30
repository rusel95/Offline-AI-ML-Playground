//
//  ResumableDownloadsView.swift
//  Offline AI&ML Playground
//
//  Created by Assistant on 07.01.2025.
//

import SwiftUI

struct ResumableDownloadsView: View {
    let modelsWithResumeData: [String]
    let availableModels: [AIModel]
    let onResume: (AIModel) -> Void
    let onDelete: (String) -> Void
    
    var body: some View {
        if !modelsWithResumeData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text("Interrupted Downloads")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    ForEach(modelsWithResumeData, id: \.self) { modelId in
                        if let model = availableModels.first(where: { $0.id == modelId }) {
                            ResumableDownloadRow(
                                model: model,
                                onResume: { onResume(model) },
                                onDelete: { onDelete(modelId) }
                            )
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

struct ResumableDownloadRow: View {
    let model: AIModel
    let onResume: () -> Void
    let onDelete: () -> Void
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Download interrupted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                
                Button(action: onResume) {
                    HStack(spacing: 4) {
                        Image(systemName: networkMonitor.isConnected ? "arrow.down.circle" : "wifi.slash")
                            .font(.caption)
                        Text(networkMonitor.isConnected ? "Resume" : "Offline")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(networkMonitor.isConnected ? .white : .gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(networkMonitor.isConnected ? Color.orange : Color.gray.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!networkMonitor.isConnected)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
        )
    }
}

#Preview {
    ResumableDownloadsView(
        modelsWithResumeData: ["test-model-1", "test-model-2"],
        availableModels: [
            AIModel(
                id: "test-model-1",
                name: "Test Model 1",
                description: "A test model",
                huggingFaceRepo: "test/model1",
                filename: "model.safetensors",
                sizeInBytes: 100_000_000,
                type: .general,
                tags: [],
                isGated: false,
                provider: .other
            ),
            AIModel(
                id: "test-model-2",
                name: "Test Model 2",
                description: "Another test model",
                huggingFaceRepo: "test/model2",
                filename: "model.safetensors",
                sizeInBytes: 200_000_000,
                type: .general,
                tags: [],
                isGated: false,
                provider: .other
            )
        ],
        onResume: { _ in },
        onDelete: { _ in }
    )
    .padding()
}