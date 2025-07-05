//
//  PerformanceSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Performance Settings View
struct PerformanceSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
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
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            PerformanceSettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Model Configuration")
    }
} 