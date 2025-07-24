//
//  PerformanceSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Performance Settings View
struct PerformanceSettingsView: View {
    @EnvironmentObject private var viewModel: PerformanceSettingsViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Real-time Performance Statistics Card
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 8) {
                    // Performance monitoring toggle
                    HStack {
                        Image(systemName: viewModel.isMonitoring ? "play.circle.fill" : "play.circle")
                            .foregroundStyle(viewModel.isMonitoring ? .green : .secondary)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Real-time Monitoring")
                                .font(.headline)
                            Text(viewModel.isMonitoring ? "Active" : "Stopped")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { viewModel.isMonitoring },
                            set: { isOn in
                                if isOn {
                                    viewModel.startMonitoring()
                                } else {
                                    viewModel.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                    }
                    // Performance metrics - only show when monitoring is enabled
                    if viewModel.isMonitoring {
                        // CPU Usage
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.blue)
                                .font(.title2)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CPU Usage")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                ProgressView(value: viewModel.cpuUsage, total: 100)
                                    .progressViewStyle(LinearProgressViewStyle(tint: cpuUsageColor(viewModel.cpuUsage)))
                                    .scaleEffect(y: 0.8)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.formattedCPUUsage)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(cpuUsageColor(viewModel.cpuUsage))
                                
                                Text(cpuUsageStatus(viewModel.cpuUsage))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        
                        // App Memory Usage
                        HStack {
                            Image(systemName: "app.badge")
                                .foregroundStyle(.blue)
                                .font(.title2)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Memory")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                ProgressView(value: min(max(viewModel.appMemoryPercentage, 0.0), 5.0), total: 5.0)
                                    .progressViewStyle(LinearProgressViewStyle(tint: appMemoryUsageColor(viewModel.appMemoryPercentage)))
                                    .scaleEffect(y: 0.8)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(viewModel.formattedAppMemoryUsed)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(appMemoryUsageColor(viewModel.appMemoryPercentage))
                                
                                Text(appMemoryUsageStatus(viewModel.appMemoryUsedMB))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(12)
                        
                        // System Memory Usage
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundStyle(.purple)
                                .font(.title2)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("System Memory")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                ProgressView(value: viewModel.systemMemoryPercentage, total: 100)
                                    .progressViewStyle(LinearProgressViewStyle(tint: systemMemoryUsageColor(viewModel.systemMemoryPercentage)))
                                    .scaleEffect(y: 0.8)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(viewModel.formattedSystemMemoryUsed)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(systemMemoryUsageColor(viewModel.systemMemoryPercentage))
                                    
                                    Text("(\(viewModel.formattedSystemMemoryPercentage))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text(systemMemoryUsageStatus(viewModel.systemMemoryPercentage))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(12)
                    }
                    
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
        .onAppear {
            // Auto-start monitoring when view appears  
            viewModel.startMonitoring()
        }
        .onDisappear {
            // Stop monitoring when view disappears to save resources
            viewModel.stopMonitoring()
        }
    }
    
    // MARK: - Helper Methods
    
    private func cpuUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<30:
            return .green
        case 30..<70:
            return .orange
        default:
            return .red
        }
    }
    
    private func appMemoryUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<1.0:  // Under 1% of total system memory
            return .green
        case 1.0..<3.0:  // 1-3% of total system memory
            return .orange
        default:  // Over 3% of total system memory
            return .red
        }
    }
    
    private func systemMemoryUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<60:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
    
    private func cpuUsageStatus(_ usage: Double) -> String {
        switch usage {
        case 0..<30:
            return "Low"
        case 30..<70:
            return "Moderate"
        default:
            return "High"
        }
    }
    
    private func appMemoryUsageStatus(_ usedMB: Double) -> String {
        switch usedMB {
        case 0..<100:
            return "Efficient"
        case 100..<500:
            return "Moderate"
        case 500..<1000:
            return "Heavy"
        default:
            return "Very Heavy"
        }
    }
    
    private func systemMemoryUsageStatus(_ usage: Double) -> String {
        switch usage {
        case 0..<60:
            return "Good"
        case 60..<80:
            return "Moderate"
        default:
            return "High Pressure"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        List {
            PerformanceSettingsView()
        }
        .navigationTitle("Performance")
    }
    .environmentObject(PerformanceSettingsViewModel())
} 
