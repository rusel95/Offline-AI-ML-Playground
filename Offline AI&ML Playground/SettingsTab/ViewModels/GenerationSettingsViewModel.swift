//
//  GenerationSettingsViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import SwiftUI
import Combine

@MainActor
class GenerationSettingsViewModel: ObservableObject {
    @Published var temperature: Float {
        didSet { GenerationSettings.shared.temperature = temperature }
    }
    @Published var topP: Float {
        didSet { GenerationSettings.shared.topP = topP }
    }
    @Published var maxOutputTokens: Int {
        didSet { GenerationSettings.shared.maxOutputTokens = maxOutputTokens }
    }

    init() {
        temperature = GenerationSettings.shared.temperature
        topP = GenerationSettings.shared.topP
        maxOutputTokens = GenerationSettings.shared.maxOutputTokens
    }
}




