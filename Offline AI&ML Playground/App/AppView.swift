//
//  AppView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

struct AppView: View {
    enum Tab: String {
        case chat
        case download
        case settings
    }

    @State private var selectedTab: Tab = .chat

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                SimpleChatView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(Tab.chat)
            
            NavigationView {
                SimpleDownloadView()
            }
            .tabItem {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .tag(Tab.download)
            
            NavigationView {
                SimpleSettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(Tab.settings)
        }
    }
}



#Preview {
    AppView()
} 