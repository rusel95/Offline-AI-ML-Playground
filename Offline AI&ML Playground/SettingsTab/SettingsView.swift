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
        #if os(macOS)
        MacOSSettingsView(settingsManager: settingsManager)
        #else
        iOSSettingsView(settingsManager: settingsManager)
        #endif
    }
}

// MARK: - iOS Settings View
struct iOSSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                PerformanceSettingsView(settingsManager: settingsManager)
                StorageSettingsView(settingsManager: settingsManager)
                AboutSettingsView()
            }
        }
    }
}

// MARK: - macOS Settings View
struct MacOSSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var selectedSection: SettingsSection = .performance
    
    enum SettingsSection: String, CaseIterable {
        case performance = "Performance"
        case storage = "Storage"
        case about = "About"
        
        var icon: String {
            switch self {
            case .performance: return "speedometer"
            case .storage: return "externaldrive"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, id: \.self, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.rawValue, systemImage: section.icon)
                        .font(.headline)
                }
            }
            .navigationTitle("Settings")
            .listStyle(SidebarListStyle())
        } detail: {
            switch selectedSection {
            case .performance:
                PerformanceSettingsView(settingsManager: settingsManager)
                    .navigationTitle("Performance")
            case .storage:
                StorageSettingsView(settingsManager: settingsManager)
                    .navigationTitle("Storage")
            case .about:
                AboutSettingsView()
                    .navigationTitle("About")
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Settings Manager
@MainActor
class SettingsManager: ObservableObject {
    // Add settings properties here as needed
}

#Preview {
    SimpleSettingsView()
} 
