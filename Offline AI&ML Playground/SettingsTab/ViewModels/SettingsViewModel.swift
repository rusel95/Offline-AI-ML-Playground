//
//  SettingsViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

// MARK: - Settings Section Model
enum SettingsSection: String, CaseIterable, Identifiable {
    case performance = "Performance"
    case generation = "Generation"
    case storage = "Storage"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .performance: return "speedometer"
        case .generation: return "slider.horizontal.3"
        case .storage: return "internaldrive"
        case .about: return "info.circle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .performance: return .green
        case .generation: return .purple
        case .storage: return .orange
        case .about: return .blue
        }
    }
}

// MARK: - Main Settings ViewModel
@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sections: [SettingsSection] = SettingsSection.allCases
    @Published var selectedSection: SettingsSection?
    
    // Sub-ViewModels
    let performanceViewModel: PerformanceSettingsViewModel
    let generationViewModel: GenerationSettingsViewModel
    let storageViewModel: StorageSettingsViewModel
    let aboutViewModel: AboutSettingsViewModel
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.performanceViewModel = PerformanceSettingsViewModel()
        self.generationViewModel = GenerationSettingsViewModel()
        self.storageViewModel = StorageSettingsViewModel()
        self.aboutViewModel = AboutSettingsViewModel()
        
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Could add any cross-viewmodel bindings here if needed
    }
    
    // MARK: - Public Methods
    func viewModelForSection(_ section: SettingsSection) -> any ObservableObject {
        switch section {
        case .performance:
            return performanceViewModel
        case .generation:
            return generationViewModel
        case .storage:
            return storageViewModel
        case .about:
            return aboutViewModel
        }
    }
    
    func onAppear() {
        // Perform any initialization when settings view appears
        performanceViewModel.startMonitoring()
        storageViewModel.refreshStorageInfo()
    }
    
    func onDisappear() {
        // Clean up when settings view disappears
        performanceViewModel.cleanup()
    }
}
