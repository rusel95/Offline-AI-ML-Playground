//
//  StorageSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

// MARK: - Storage Settings View
struct StorageSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var downloadManager = ModelDownloadManager()
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearHistoryAlert = false
    
    var body: some View {
        Section("Storage Management") {
            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.brown)
                VStack(alignment: .leading) {
                    Text("Storage Used")
                    Text("\(downloadManager.formattedStorageUsed) / \(downloadManager.formattedTotalStorage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Add storage progress indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int((downloadManager.storageUsed / downloadManager.totalStorage) * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    ProgressView(value: downloadManager.storageUsed, total: downloadManager.totalStorage)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .scaleEffect(y: 0.8)
                }
            }
            
            Button {
                showingClearHistoryAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Clear All Chat History")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .alert("Clear All Chat History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllChatHistory()
            }
        } message: {
            Text("This will permanently delete all your chat conversations. This action cannot be undone.")
        }
    }
    
    private func clearAllChatHistory() {
        let historyManager = ChatHistoryManager(modelContext: modelContext)
        historyManager.deleteAllConversations()
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