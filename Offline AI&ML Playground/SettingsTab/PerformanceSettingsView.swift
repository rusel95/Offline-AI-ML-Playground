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
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var performanceMonitor = PerformanceMonitor()
    
    var body: some View {
        Group {
            // Real-time Performance Statistics Section
            Section("System Performance") {
                VStack(spacing: 12) {
                    // Performance monitoring toggle
                    HStack {
                        Image(systemName: performanceMonitor.isMonitoring ? "play.circle.fill" : "play.circle")
                            .foregroundStyle(performanceMonitor.isMonitoring ? .green : .secondary)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Real-time Monitoring")
                                .font(.headline)
                            Text(performanceMonitor.isMonitoring ? "Active" : "Stopped")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { performanceMonitor.isMonitoring },
                            set: { isOn in
                                if isOn {
                                    performanceMonitor.startMonitoring()
                                } else {
                                    performanceMonitor.stopMonitoring()
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle())
                    }
                    .padding(.vertical, 4)
                    
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
                            
                            ProgressView(value: performanceMonitor.currentStats.cpuUsage, total: 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: cpuUsageColor(performanceMonitor.currentStats.cpuUsage)))
                                .scaleEffect(y: 0.8)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(performanceMonitor.currentStats.formattedCPUUsage)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(cpuUsageColor(performanceMonitor.currentStats.cpuUsage))
                            
                            Text(cpuUsageStatus(performanceMonitor.currentStats.cpuUsage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Memory Usage
                    HStack {
                        Image(systemName: "memorychip")
                            .foregroundStyle(.purple)
                            .font(.title2)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Memory Usage")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ProgressView(value: performanceMonitor.currentStats.memoryUsage, total: 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: memoryUsageColor(performanceMonitor.currentStats.memoryUsage)))
                                .scaleEffect(y: 0.8)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(performanceMonitor.currentStats.formattedMemoryUsed)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(memoryUsageColor(performanceMonitor.currentStats.memoryUsage))
                                
                                Text("(\(performanceMonitor.currentStats.formattedMemoryUsage))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text(memoryUsageStatus(performanceMonitor.currentStats.memoryUsage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Last updated timestamp
                    if performanceMonitor.isMonitoring {
                        HStack {
                            Spacer()
                            Text("Last updated: \(performanceMonitor.currentStats.timestamp, formatter: timeFormatter)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Model Configuration Section
            Section("Model Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "thermometer")
                            .foregroundColor(.orange)
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.1f", settingsManager.temperature))
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $settingsManager.temperature, in: 0.0...2.0, step: 0.1)
                        .accentColor(.orange)
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "speedometer")
                            .foregroundColor(.green)
                        Text("Max Tokens")
                        Spacer()
                        Text("\(settingsManager.maxTokens)")
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(settingsManager.maxTokens) },
                        set: { settingsManager.maxTokens = Int($0) }
                    ), in: 100...4000, step: 100)
                        .accentColor(.green)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.blue)
                    Text("Performance Mode")
                    Spacer()
                    Picker("Performance Mode", selection: $settingsManager.performanceMode) {
                        ForEach(PerformanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .onAppear {
            // Auto-start monitoring when view appears
            performanceMonitor.startMonitoring()
        }
        .onDisappear {
            // Stop monitoring when view disappears to save resources
            performanceMonitor.stopMonitoring()
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
    
    private func memoryUsageColor(_ usage: Double) -> Color {
        switch usage {
        case 0..<50:
            return .green
        case 50..<80:
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
    
    private func memoryUsageStatus(_ usage: Double) -> String {
        switch usage {
        case 0..<50:
            return "Normal"
        case 50..<80:
            return "Elevated"
        default:
            return "High"
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
            PerformanceSettingsView(settingsManager: SettingsManager())
        }
        .navigationTitle("Performance")
    }
} 