//
//  UserDefaultsStorage.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation

final class UserDefaultsStorage: SettingsStorageProtocol {
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    func getValue<T>(for key: String, defaultValue: T) -> T {
        return userDefaults.object(forKey: key) as? T ?? defaultValue
    }
    
    func setValue<T>(_ value: T, for key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func removeValue(for key: String) {
        userDefaults.removeObject(forKey: key)
    }
}

// MARK: - Settings Keys

enum SettingsKeys {
    // Chat settings
    static let chatUseMaxContext = "chatUseMaxContext"
    static let chatCustomContextSize = "chatCustomContextSize"
    static let lastSelectedModelID = "lastSelectedModelID"
    
    // Generation settings
    static let temperature = "gen.temperature"
    static let topP = "gen.topP"
    static let maxOutputTokens = "gen.maxOutputTokens"
    static let systemPrompt = "gen.systemPrompt"
    
    // App settings
    static let showPerformanceMonitoring = "showPerformanceMonitoring"
    static let enableDebugLogging = "enableDebugLogging"
}