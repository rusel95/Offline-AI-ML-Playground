//
//  ModelHealthView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import SwiftUI

struct ModelHealthView: View {
    @State private var healthReport: ModelHealthCheck.HealthReport?
    @State private var isRunningCheck = false
    @State private var isFixingIssues = false
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Label("Model Health", systemImage: "heart.text.square.fill")
                    .font(.headline)
                
                Spacer()
                
                Button(action: runHealthCheck) {
                    if isRunningCheck {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Check", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRunningCheck || isFixingIssues)
            }
            
            // Health Summary
            if let report = healthReport {
                VStack(alignment: .leading, spacing: 12) {
                    // Overview Cards
                    HStack(spacing: 12) {
                        HealthCard(
                            title: "Total Models",
                            value: "\(report.totalModels)",
                            icon: "square.stack.3d.up",
                            color: .blue
                        )
                        
                        HealthCard(
                            title: "Healthy",
                            value: "\(report.healthyModels)",
                            icon: "checkmark.circle.fill",
                            color: .green
                        )
                        
                        HealthCard(
                            title: "Issues",
                            value: "\(report.modelsWithIssues)",
                            icon: "exclamationmark.triangle.fill",
                            color: report.modelsWithIssues > 0 ? .orange : .gray
                        )
                    }
                    
                    // Disk Usage
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Disk Usage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Image(systemName: "internaldrive")
                                .foregroundStyle(.secondary)
                            Text(ByteCountFormatter.string(
                                fromByteCount: report.totalDiskUsage,
                                countStyle: .file
                            ))
                            .font(.title3)
                            .fontWeight(.medium)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Fix Button
                    if report.modelsWithIssues > 0 {
                        Button(action: fixAllIssues) {
                            if isFixingIssues {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Fixing Issues...")
                                }
                            } else {
                                Label("Fix All Issues", systemImage: "wrench.and.screwdriver.fill")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFixingIssues || isRunningCheck)
                    }
                    
                    // Recommendations
                    if !report.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ForEach(report.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.caption)
                                    Text(recommendation)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    
                    // Detailed Model List
                    if showDetails {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Model Details")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            ForEach(report.modelHealths, id: \.modelId) { health in
                                ModelHealthRow(health: health)
                            }
                        }
                    }
                    
                    Button(action: { showDetails.toggle() }) {
                        HStack {
                            Text(showDetails ? "Hide Details" : "Show Details")
                            Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                // No health check run yet
                VStack(spacing: 16) {
                    Image(systemName: "heart.text.square")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("Run a health check to see model status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10)
        .onAppear {
            runHealthCheck()
        }
    }
    
    private func runHealthCheck() {
        isRunningCheck = true
        
        Task {
            let report = await ModelHealthCheck.runHealthCheck()
            await MainActor.run {
                self.healthReport = report
                self.isRunningCheck = false
            }
        }
    }
    
    private func fixAllIssues() {
        isFixingIssues = true
        
        Task {
            let _ = await ModelHealthCheck.fixAllIssues()
            await MainActor.run {
                self.isFixingIssues = false
                // Run health check again to update status
                runHealthCheck()
            }
        }
    }
}

struct HealthCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ModelHealthRow: View {
    let health: ModelHealthCheck.ModelHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: health.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(health.isHealthy ? .green : .orange)
                    .font(.caption)
                
                Text(health.modelName)
                    .font(.caption)
                    .lineLimit(1)
                
                Spacer()
                
                Text(ByteCountFormatter.string(
                    fromByteCount: health.sizeOnDisk,
                    countStyle: .file
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            
            if !health.isHealthy {
                ForEach(health.issues, id: \.self) { issue in
                    Text("• \(issue)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.leading, 20)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ModelHealthView()
        .frame(maxWidth: 400)
        .padding()
}