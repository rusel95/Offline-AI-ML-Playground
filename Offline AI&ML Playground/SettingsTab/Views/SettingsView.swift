//
//  SettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(viewModel.sections) { section in
                    SettingsSectionView(
                        section: section,
                        viewModel: viewModel
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }
}

struct SettingsSectionView: View {
    let section: SettingsSection
    let viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with modern styling
            HStack {
                Image(systemName: section.icon)
                    .foregroundStyle(section.iconColor)
                    .font(.title2)
                Text(section.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal, 4)
            
            // Section content
            Group {
                switch section {
                case .performance:
                    PerformanceSettingsView()
                        .environmentObject(viewModel.performanceViewModel)
                case .generation:
                    GenerationSettingsView()
                        .environmentObject(viewModel.generationViewModel)
                case .storage:
                    StorageSettingsView()
                        .environmentObject(viewModel.storageViewModel)
                case .logging:
                    LoggingSettingsView()
                case .about:
                    AboutSettingsView()
                        .environmentObject(viewModel.aboutViewModel)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
} 
