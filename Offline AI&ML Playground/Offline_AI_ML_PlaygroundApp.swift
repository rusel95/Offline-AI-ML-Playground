//
//  Offline_AI_ML_PlaygroundApp.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct Offline_AI_ML_PlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
        }
        .modelContainer(for: [Conversation.self, StoredChatMessage.self])
    }
}
