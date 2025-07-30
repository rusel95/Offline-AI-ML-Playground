//
//  MLXDownloadView.swift
//  Offline AI&ML Playground
//
//  Created by Assistant on 07.01.2025.
//

import SwiftUI

struct MLXDownloadView: View {
    let model: AIModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var downloader = MLXModelDownloader()
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Model Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.largeTitle)
                            .foregroundStyle(.accent)
                        
                        VStack(alignment: .leading) {
                            Text(model.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(model.formattedSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Download Status
                if downloader.isDownloading {
                    VStack(spacing: 16) {
                        ProgressView(value: downloader.downloadProgress) {
                            Text(downloader.downloadStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(Int(downloader.downloadProgress * 100))%")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        Button("Cancel") {
                            downloader.cancelDownload()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        Text("This will download all necessary files for the MLX model:")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Label("model.safetensors", systemImage: "doc.fill")
                            Label("config.json", systemImage: "doc.text.fill")
                            Label("tokenizer files", systemImage: "doc.text.fill")
                        }
                        .font(.caption)
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                        
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Download") {
                                startDownload()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Download MLX Model")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Download Error", isPresented: $showError) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text(downloader.lastError ?? "Unknown error occurred")
            }
        }
    }
    
    private func startDownload() {
        Task {
            do {
                try await downloader.downloadMLXModel(model)
                
                // Success - dismiss after a short delay
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    downloader.lastError = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    MLXDownloadView(model: AIModel(
        id: "test-model",
        name: "Test Model",
        description: "A test MLX model",
        huggingFaceRepo: "mlx-community/test-model",
        filename: "model.safetensors",
        sizeInBytes: 100_000_000,
        type: .general,
        tags: ["test"],
        isGated: false,
        provider: .other
    ))
}