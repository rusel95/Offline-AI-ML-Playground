//
//  AppView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

struct AppView: View {
    var body: some View {
        TabView {
            ChatView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("Chat")
                }
            
            SimpleDownloadView()
                .tabItem {
                    Image(systemName: "arrow.down.circle")
                    Text("Download")
                }
            
            SimpleSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

// MARK: - Simple Download View

struct SimpleDownloadView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Download Manager")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Download and manage AI models")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Browse Models") {
                    // Action to browse models
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Download")
        }
    }
}

// MARK: - Simple Settings View

struct SimpleSettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Appearance") {
                    HStack {
                        Image(systemName: "paintbrush")
                            .foregroundColor(.blue)
                        Text("Theme")
                        Spacer()
                        Text("System")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Model Settings") {
                    HStack {
                        Image(systemName: "cpu")
                            .foregroundColor(.green)
                        Text("Performance Mode")
                        Spacer()
                        Text("Balanced")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("Temperature")
                        Spacer()
                        Text("0.7")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Storage") {
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(.purple)
                        Text("Clear Cache")
                        Spacer()
                        Button("Clear") {
                            // Clear cache action
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    AppView()
} 