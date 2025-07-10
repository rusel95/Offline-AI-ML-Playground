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
        iOSAppView()
    }
}

// MARK: - iOS App View
struct iOSAppView: View {
    var body: some View {
        TabView {
            NavigationView {
                SimpleChatView()
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            
            NavigationView {
                SimpleDownloadView()
            }
            .tabItem {
                Label("Download", systemImage: "arrow.down.circle")
            }
            
            NavigationView {
                SimpleSettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

#Preview {
    AppView()
} 