//
//  StorageSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Storage Settings View
struct StorageSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
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
            }
            
            HStack {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                Text("Clear All Chat History")
                Spacer()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            StorageSettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Storage Settings")
    }
} 