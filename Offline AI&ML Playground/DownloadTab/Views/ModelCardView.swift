//
//  ModelCardView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Model Card View
struct ModelCardView: View {
    let model: AIModel
    @ObservedObject var sharedManager: SharedModelManager
    @State private var showingDetailedInfo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model header with minimal info
            HStack(alignment: .center, spacing: 12) {
                // Model brand icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(model.displayColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: model.displayIcon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(model.displayColor)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    HStack {
                        Text("Storage:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(model.formattedSize)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Regular Memory:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(model.formattedRegularMemory)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Max Memory:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(model.formattedMaxMemory)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Info button
                Button(action: {
                    showingDetailedInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            // Download status and action
            ModelActionView(model: model, sharedManager: sharedManager)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingDetailedInfo) {
            ModelDetailedInfoView(model: model)
        }
    }
}

// MARK: - Enhanced Model Detailed Info View
struct ModelDetailedInfoView: View {
    let model: AIModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview
    
    private enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case capabilities = "Capabilities"
        case performance = "Performance"
        case technical = "Technical"
        
        var iconName: String {
            switch self {
            case .overview: return "info.circle"
            case .capabilities: return "brain.head.profile"
            case .performance: return "speedometer"
            case .technical: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Enhanced Header with gradient background
                headerView
                    .background(
                        LinearGradient(
                            colors: [model.displayColor.opacity(0.1), model.displayColor.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Tab selector
                tabSelector
                
                // Content based on selected tab
                ScrollView {
                    LazyVStack(spacing: 20) {
                        switch selectedTab {
                        case .overview:
                            overviewSection
                        case .capabilities:
                            capabilitiesSection
                        case .performance:
                            performanceSection
                        case .technical:
                            technicalSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticFeedback.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Enhanced model icon with glow effect
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(model.displayColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .shadow(color: model.displayColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: model.displayIcon)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [model.displayColor, model.displayColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    // Provider badge
                    HStack(spacing: 6) {
                        Image(systemName: model.provider.iconName)
                            .font(.caption)
                        Text(model.provider.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(model.provider.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(model.provider.color.opacity(0.1))
                    )
                }
                
                Spacer()
            }
            
            // Quick stats
            HStack(spacing: 16) {
                quickStatView(title: "Size", value: model.formattedSize, icon: "internaldrive")
                quickStatView(title: "Type", value: model.type.displayName, icon: "cpu")
                quickStatView(title: "Memory", value: model.formattedRegularMemory, icon: "memorychip")
            }
        }
        .padding()
    }
    
    // MARK: - Tab Selector
    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        HapticFeedback.selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? Color.accentColor : Color(.systemGray5))
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Overview Section
    private var overviewSection: some View {
        VStack(spacing: 16) {
            // Use Cases
            sectionCard(title: "Primary Use Cases", icon: "lightbulb") {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(model.useCases.prefix(6), id: \.self) { useCase in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text(useCase)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                }
            }
            
            // Strengths
            sectionCard(title: "Key Strengths", icon: "star") {
                LazyVGrid(columns: [
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(model.strengths.prefix(4), id: \.self) { strength in
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(strength)
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Capabilities Section
    private var capabilitiesSection: some View {
        VStack(spacing: 16) {
            // Recommended Tasks
            sectionCard(title: "Recommended Tasks", icon: "list.bullet.clipboard") {
                LazyVStack(spacing: 12) {
                    ForEach(model.recommendedTasks, id: \.title) { task in
                        taskRow(task: task)
                    }
                }
            }
            
            // All Use Cases
            sectionCard(title: "All Capabilities", icon: "brain.head.profile") {
                LazyVGrid(columns: [
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(model.useCases, id: \.self) { useCase in
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(model.displayColor)
                                .font(.caption)
                            Text(useCase)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Performance Section
    private var performanceSection: some View {
        VStack(spacing: 16) {
            let profile = model.performanceProfile
            
            sectionCard(title: "Performance Profile", icon: "speedometer") {
                VStack(spacing: 12) {
                    performanceRow(title: "Speed", level: profile.speed)
                    performanceRow(title: "Memory Usage", level: profile.memoryUsage)
                    performanceRow(title: "Accuracy", level: profile.accuracy)
                    performanceRow(title: "Power Efficiency", level: profile.powerEfficiency)
                }
            }
            
            // Memory Requirements
            sectionCard(title: "Memory Requirements", icon: "memorychip") {
                VStack(spacing: 8) {
                    memoryRow(title: "Regular Usage", value: model.formattedRegularMemory, color: .green)
                    memoryRow(title: "Peak Usage", value: model.formattedMaxMemory, color: .orange)
                    memoryRow(title: "Storage Size", value: model.formattedSize, color: .blue)
                }
            }
        }
    }
    
    // MARK: - Technical Section
    private var technicalSection: some View {
        VStack(spacing: 16) {
            // Technical Details
            sectionCard(title: "Technical Specifications", icon: "gear") {
                VStack(spacing: 8) {
                    detailRow(title: "Repository", value: model.huggingFaceRepo)
                    detailRow(title: "Filename", value: model.filename)
                    detailRow(title: "File Size", value: model.formattedSize)
                    detailRow(title: "Model Type", value: model.type.displayName)
                    detailRow(title: "Provider", value: model.provider.displayName)
                    detailRow(title: "Gated Model", value: model.isGated ? "Yes" : "No")
                }
            }
            
            // Tags
            if !model.tags.isEmpty {
                sectionCard(title: "Tags & Categories", icon: "tag") {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100))
                    ], spacing: 8) {
                        ForEach(model.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(.systemGray6))
                                )
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func quickStatView(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
    
    private func taskRow(task: RecommendedTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.difficulty.iconName)
                .foregroundStyle(task.difficulty.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(task.difficulty.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(task.difficulty.color.opacity(0.2))
                )
                .foregroundStyle(task.difficulty.color)
        }
        .padding(.vertical, 4)
    }
    
    private func performanceRow(title: String, level: PerformanceLevel) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: level.iconName)
                    .foregroundStyle(level.color)
                    .font(.caption)
                
                Text(level.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(level.color)
            }
        }
    }
    
    private func memoryRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
            
            Spacer()
        }
    }
}

// MARK: - Preview Helper
// Preview helpers temporarily removed until SharedModelManager integration is complete
