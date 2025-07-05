//
//  AppearanceSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Appearance Settings View
struct AppearanceSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
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
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            AppearanceSettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Appearance Settings")
    }
} 