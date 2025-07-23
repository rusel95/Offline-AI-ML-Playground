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
        ScrollView {
            LazyVStack(spacing: 24) {
                // Performance Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    // Section header with modern styling
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.green)
                            .font(.title2)
                        Text("Performance")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // Performance content
                    PerformanceSettingsView()
                }
                
                // Storage Settings Section  
                VStack(alignment: .leading, spacing: 16) {
                    // Section header with modern styling
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundStyle(.orange)
                            .font(.title2)
                        Text("Storage")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // Storage content
                    StorageSettingsView()
                }
                
                // About Settings Section
                VStack(alignment: .leading, spacing: 16) {
                    // Section header with modern styling
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                            .font(.title2)
                        Text("About")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    
                    // About content
                    AboutSettingsView()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    SimpleSettingsView()
} 
