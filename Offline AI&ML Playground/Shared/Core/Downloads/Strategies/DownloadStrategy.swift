//
//  DownloadStrategy.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation

/// Protocol for different download strategies (Open/Closed Principle)
public protocol DownloadStrategy {
    /// Download a model using the specific strategy
    func download(model: AIModel, to directory: URL) async throws -> URL
    
    /// Validate if this strategy can handle the given model
    func canHandle(model: AIModel) -> Bool
    
    /// Get required files for this model format
    func getRequiredFiles(for model: AIModel) -> [String]
}

/// Factory for creating appropriate download strategies
public class DownloadStrategyFactory {
    
    private var strategies: [DownloadStrategy]
    
    public init() {
        // Register all available strategies
        self.strategies = [
            GGUFDownloadStrategy(),
            SafetensorsDownloadStrategy(),
            MultiPartDownloadStrategy(),
            MLXDownloadStrategy()
        ]
    }
    
    /// Get the appropriate strategy for a model
    public func getStrategy(for model: AIModel) throws -> DownloadStrategy {
        guard let strategy = strategies.first(where: { $0.canHandle(model: model) }) else {
            throw ModelError.formatError("No download strategy available for model format")
        }
        return strategy
    }
    
    /// Register a new strategy (Open for extension)
    public func registerStrategy(_ strategy: DownloadStrategy) {
        strategies.append(strategy)
    }
}