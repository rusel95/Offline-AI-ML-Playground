//
//  GenerationSettings.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation

@MainActor
final class GenerationSettings: ObservableObject, GenerationSettingsProtocol {
    static let shared = GenerationSettings()
    
    private let storage: SettingsStorageProtocol

    @Published var temperature: Float {
        didSet { storage.setValue(temperature, for: SettingsKeys.temperature) }
    }

    @Published var topP: Float {
        didSet { storage.setValue(topP, for: SettingsKeys.topP) }
    }

    @Published var maxOutputTokens: Int {
        didSet { storage.setValue(maxOutputTokens, for: SettingsKeys.maxOutputTokens) }
    }

    @Published var systemPrompt: String {
        didSet { storage.setValue(systemPrompt, for: SettingsKeys.systemPrompt) }
    }

    init(storage: SettingsStorageProtocol = UserDefaultsStorage()) {
        self.storage = storage
        
        self.temperature = storage.getValue(for: SettingsKeys.temperature, defaultValue: 0.7)
        self.topP = storage.getValue(for: SettingsKeys.topP, defaultValue: 0.9)
        self.maxOutputTokens = storage.getValue(for: SettingsKeys.maxOutputTokens, defaultValue: 512)
        self.systemPrompt = storage.getValue(for: SettingsKeys.systemPrompt, defaultValue: "")
    }
}



