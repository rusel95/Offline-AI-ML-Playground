//
//  GenerationSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import SwiftUI

struct GenerationSettingsView: View {
    @EnvironmentObject private var viewModel: GenerationSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // System prompt
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "text.quote")
                        .foregroundStyle(.teal)
                    Text("System prompt (optional)")
                        .font(.headline)
                }
                TextEditor(text: Binding(
                    get: { GenerationSettings.shared.systemPrompt },
                    set: { GenerationSettings.shared.systemPrompt = $0 }
                ))
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            // Temperature
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Temperature")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.temperature))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(viewModel.temperature) },
                    set: { viewModel.temperature = Float($0) }
                ), in: 0.0...1.5, step: 0.05)
            }

            // Top-p
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar")
                        .foregroundStyle(.blue)
                    Text("Top-p (nucleus)")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.topP))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(viewModel.topP) },
                    set: { viewModel.topP = Float($0) }
                ), in: 0.1...1.0, step: 0.05)
            }

            // Max output tokens
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "number")
                        .foregroundStyle(.purple)
                    Text("Max output tokens")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.maxOutputTokens)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(viewModel.maxOutputTokens) },
                    set: { viewModel.maxOutputTokens = Int($0) }
                ), in: 16...2048, step: 16)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}



