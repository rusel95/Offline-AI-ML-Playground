//
//  SettingsFeature.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Settings State
struct SettingsState: Equatable {
    var notificationsEnabled: Bool = true
    var backgroundDownloadsEnabled: Bool = true
    var maxConcurrentDownloads: Int = 2
    var autoDeleteOldModels: Bool = false
    var maxStorageSize: Int64 = 50_000_000_000 // 50GB
    var currentStorageUsed: Int64 = 0
    var appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    var buildNumber: String = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var storageUsagePercentage: Double {
        guard maxStorageSize > 0 else { return 0 }
        return Double(currentStorageUsed) / Double(maxStorageSize)
    }
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: currentStorageUsed, countStyle: .file)
    }
    
    var formattedMaxStorage: String {
        ByteCountFormatter.string(fromByteCount: maxStorageSize, countStyle: .file)
    }
}

// MARK: - Settings Actions
enum SettingsAction: Equatable {
    case viewAppeared
    case notificationsToggled(Bool)
    case backgroundDownloadsToggled(Bool)
    case maxConcurrentDownloadsChanged(Int)
    case autoDeleteToggled(Bool)
    case maxStorageSizeChanged(Int64)
    case clearCache
    case resetSettings
    
    // Internal actions
    case storageUsageUpdated(Int64)
    case cacheCleared
    case settingsReset
}

// MARK: - Settings Reducer
@MainActor
class SettingsReducer: ObservableObject {
    @Published private(set) var state = SettingsState()
    
    func send(_ action: SettingsAction) {
        Task {
            await reduce(action)
        }
    }
    
    private func reduce(_ action: SettingsAction) async {
        switch action {
        case .viewAppeared:
            // Calculate current storage usage
            await send(.storageUsageUpdated(calculateStorageUsage()))
            
        case let .notificationsToggled(enabled):
            state.notificationsEnabled = enabled
            // TODO: Save to UserDefaults
            
        case let .backgroundDownloadsToggled(enabled):
            state.backgroundDownloadsEnabled = enabled
            // TODO: Save to UserDefaults
            
        case let .maxConcurrentDownloadsChanged(count):
            state.maxConcurrentDownloads = max(1, min(5, count)) // Clamp between 1-5
            // TODO: Save to UserDefaults
            
        case let .autoDeleteToggled(enabled):
            state.autoDeleteOldModels = enabled
            // TODO: Save to UserDefaults
            
        case let .maxStorageSizeChanged(size):
            state.maxStorageSize = size
            // TODO: Save to UserDefaults
            
        case .clearCache:
            // TODO: Implement cache clearing
            await send(.cacheCleared)
            
        case .resetSettings:
            // Reset to defaults
            state = SettingsState()
            await send(.settingsReset)
            
        case let .storageUsageUpdated(usage):
            state.currentStorageUsed = usage
            
        case .cacheCleared:
            // Recalculate storage usage after clearing cache
            await send(.storageUsageUpdated(calculateStorageUsage()))
            
        case .settingsReset:
            print("Settings have been reset to defaults")
        }
    }
    
    private func calculateStorageUsage() -> Int64 {
        // TODO: Implement actual storage calculation
        // For now, return a simulated value
        return 5_000_000_000 // 5GB
    }
} 