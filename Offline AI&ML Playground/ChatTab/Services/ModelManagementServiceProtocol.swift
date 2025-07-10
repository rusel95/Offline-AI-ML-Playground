//
//  ModelManagementServiceProtocol.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation

// MARK: - Model Management Service Protocol
/// Protocol defining the interface for AI model management
/// This protocol abstracts the model downloading and availability checking functionality
protocol ModelManagementServiceProtocol {
    /// Loads the list of downloaded models from local storage
    func loadDownloadedModels()
    
    /// Refreshes the list of available models from remote sources
    func refreshAvailableModels() async
    
    /// Returns the list of currently downloaded models
    /// - Returns: Array of downloaded AI models
    func getDownloadedModels() -> [AIModel]
}

// MARK: - Preview Helper
struct MockModelManagementService: ModelManagementServiceProtocol {
    func loadDownloadedModels() {
        // Mock implementation
    }
    
    func refreshAvailableModels() async {
        // Mock implementation
    }
    
    func getDownloadedModels() -> [AIModel] {
        // Return sample models for preview
        return AIModel.sampleModels
    }
}

#Preview("Model Management Service Protocol") {
    VStack(spacing: 20) {
        Text("Model Management Service Protocol")
            .font(.title)
            .fontWeight(.bold)
        
        Text("This protocol defines the interface for AI model management including:")
            .font(.subheadline)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("• loadDownloadedModels() - Load local model list")
            Text("• refreshAvailableModels() - Update from remote sources")
            Text("• getDownloadedModels() - Get available models")
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .padding()
} 