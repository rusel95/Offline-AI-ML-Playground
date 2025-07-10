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
        VStack(spacing: 0) {
            List {
                PerformanceSettingsView(settingsManager: settingsManager)
                StorageSettingsView(settingsManager: settingsManager)
                AboutSettingsView()
            }
        }
    }
}

// MARK: - Settings Manager
@MainActor
class SettingsManager: ObservableObject {

    

}





#Preview {
    SimpleSettingsView()
} 
