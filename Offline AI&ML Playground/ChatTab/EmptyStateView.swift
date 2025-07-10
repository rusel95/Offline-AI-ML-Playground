//
//  EmptyStateView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Empty State View
struct EmptyStateView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        iOSEmptyStateView(viewModel: viewModel)
    }
}

// MARK: - iOS Empty State View
struct iOSEmptyStateView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Model status icon
            if viewModel.selectedModel != nil {
                Image(systemName: "message")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor.opacity(0.3))
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                if viewModel.selectedModel != nil {
                    Text("Start a conversation")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Using \(viewModel.modelDisplayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No Model Selected")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Download and select a model to start chatting")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        viewModel.showingModelPicker = true
                    } label: {
                        Text("Select Model")
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Preview
#Preview {
    EmptyStateView(viewModel: ChatViewModel())
} 