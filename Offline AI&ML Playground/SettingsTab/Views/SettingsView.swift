//
//  SettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

struct SimpleSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            List {
                PerformanceSettingsView()
                StorageSettingsView()
                AboutSettingsView()
            }
        }
    }
}

#Preview {
    SimpleSettingsView()
} 
