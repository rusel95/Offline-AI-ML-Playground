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
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - Model Configuration
                Section("Model Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "thermometer")
                                .foregroundColor(.orange)
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", settingsManager.temperature))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settingsManager.temperature, in: 0.0...2.0, step: 0.1)
                            .accentColor(.orange)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.green)
                            Text("Max Tokens")
                            Spacer()
                            Text("\(settingsManager.maxTokens)")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(settingsManager.maxTokens) },
                            set: { settingsManager.maxTokens = Int($0) }
                        ), in: 100...4000, step: 100)
                            .accentColor(.green)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.blue)
                        Text("Performance Mode")
                        Spacer()
                        Picker("Performance Mode", selection: $settingsManager.performanceMode) {
                            ForEach(PerformanceMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // MARK: - Appearance
                Section("Appearance") {
                    HStack {
                        Image(systemName: "paintbrush")
                            .foregroundColor(.purple)
                        Text("App Theme")
                        Spacer()
                        Picker("Theme", selection: $settingsManager.colorScheme) {
                            ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                                Text(scheme.displayName).tag(scheme)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.indigo)
                        Text("Font Size")
                        Spacer()
                        Picker("Font Size", selection: $settingsManager.fontSize) {
                            ForEach(FontSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                // MARK: - Privacy & Security
                Section("Privacy & Security") {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.red)
                        Text("Keep Chat History")
                        Spacer()
                        Toggle("", isOn: $settingsManager.keepChatHistory)
                            .toggleStyle(SwitchToggleStyle(tint: .red))
                    }
                    
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.gray)
                        Text("Hide Sensitive Content")
                        Spacer()
                        Toggle("", isOn: $settingsManager.hideSensitiveContent)
                            .toggleStyle(SwitchToggleStyle(tint: .gray))
                    }
                }
                
                // MARK: - Storage Management
                Section("Storage Management") {
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.brown)
                        VStack(alignment: .leading) {
                            Text("Storage Used")
                            Text("\(settingsManager.formattedStorageUsed) / \(settingsManager.formattedTotalStorage)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button("Clear Cache") {
                            settingsManager.clearCache()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                        Text("Clear All Chat History")
                        Spacer()
                        
                        Button("Clear") {
                            settingsManager.clearChatHistory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                }
                
                // MARK: - Advanced
                Section("Advanced") {
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("Developer Mode")
                        Spacer()
                        Toggle("", isOn: $settingsManager.developerMode)
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                    }
                    
                    if settingsManager.developerMode {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.gray)
                            Text("Export Logs")
                            Spacer()
                            
                            Button("Export") {
                                settingsManager.exportLogs()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                // MARK: - About
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (1)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("Made with ❤️ by Ruslan Popesku")
                            .font(.caption)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
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
    
    func clearCache() {
        // Simulate cache clearing
        print("Cache cleared")
    }
    
    func clearChatHistory() {
        // Simulate chat history clearing
        print("Chat history cleared")
    }
    
    func exportLogs() {
        // Simulate log export
        print("Logs exported")
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