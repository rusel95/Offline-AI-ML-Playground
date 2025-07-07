//
//  SettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

struct SimpleSettingsView: View {
    @StateObject private var settingsManager = SettingsManager()
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                List {
                    PerformanceSettingsView(settingsManager: settingsManager)
                    AppearanceSettingsView(settingsManager: settingsManager)
                    PrivacySettingsView(settingsManager: settingsManager)
                    StorageSettingsView(settingsManager: settingsManager)
                    AdvancedSettingsView(settingsManager: settingsManager)
                    AboutSettingsView()
                }
                
                // Version Footer
                VStack(spacing: 4) {
                    Divider()
                    
                    VStack(spacing: 2) {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Offline AI&ML Playground")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fontDesign(.monospaced)
                    }
                }
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
    }
}

// MARK: - Settings Manager
@MainActor
class SettingsManager: ObservableObject {
    @Published var temperature: Double = 0.7
    @Published var maxTokens: Int = 2000
    @Published var performanceMode: PerformanceMode = .balanced
    @Published var colorScheme: AppColorScheme = .system
    @Published var fontSize: FontSize = .medium
    @Published var keepChatHistory: Bool = true
    @Published var hideSensitiveContent: Bool = false
    @Published var developerMode: Bool = false
    
    private let storageUsed: Double = 1_500_000_000 // 1.5GB
    private let totalStorage: Double = 64_000_000_000 // 64GB
    
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var formattedTotalStorage: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalStorage), countStyle: .file)
    }
    

}

// MARK: - Enums

enum PerformanceMode: String, CaseIterable {
    case performance = "performance"
    case balanced = "balanced"
    case efficiency = "efficiency"
    
    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .balanced: return "Balanced"
        case .efficiency: return "Efficiency"
        }
    }
}

enum AppColorScheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum FontSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
}

#Preview {
    SimpleSettingsView()
} 
