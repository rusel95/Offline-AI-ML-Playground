//
//  PerformanceSettingsViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

// MARK: - Performance Status Models
enum CPUStatus {
    case low, moderate, high
    
    var label: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }
}

enum MemoryStatus {
    case efficient, moderate, heavy, veryHeavy
    
    var label: String {
        switch self {
        case .efficient: return "Efficient"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }
}

enum SystemMemoryStatus {
    case good, moderate, highPressure
    
    var label: String {
        switch self {
        case .good: return "Good"
        case .moderate: return "Moderate"
        case .highPressure: return "High Pressure"
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .moderate: return .orange
        case .highPressure: return .red
        }
    }
}

// MARK: - Performance Settings ViewModel
@MainActor
class PerformanceSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isMonitoring: Bool = false
    @Published var cpuUsage: Double = 0.0
    @Published var appMemoryUsedMB: Double = 0.0
    @Published var appMemoryPercentage: Double = 0.0
    @Published var systemMemoryUsedGB: Double = 0.0
    @Published var systemMemoryPercentage: Double = 0.0
    @Published var lastUpdateTime: Date = Date()
    
    // MARK: - Computed Properties
    var cpuStatus: CPUStatus {
        switch cpuUsage {
        case 0..<30: return .low
        case 30..<70: return .moderate
        default: return .high
        }
    }
    
    var formattedCPUUsage: String {
        String(format: "%.1f%%", cpuUsage)
    }
    
    var formattedAppMemoryUsed: String {
        if appMemoryUsedMB >= 1000 {
            return String(format: "%.2f GB", appMemoryUsedMB / 1000)
        } else {
            return String(format: "%.0f MB", appMemoryUsedMB)
        }
    }
    
    var appMemoryStatus: MemoryStatus {
        switch appMemoryUsedMB {
        case 0..<100: return .efficient
        case 100..<500: return .moderate
        case 500..<1000: return .heavy
        default: return .veryHeavy
        }
    }
    
    var appMemoryColor: Color {
        switch appMemoryPercentage {
        case 0..<1.0: return .green
        case 1.0..<3.0: return .orange
        default: return .red
        }
    }
    
    var formattedSystemMemoryUsed: String {
        String(format: "%.1f GB", systemMemoryUsedGB)
    }
    
    var formattedSystemMemoryPercentage: String {
        String(format: "%.0f%%", systemMemoryPercentage)
    }
    
    var systemMemoryStatus: SystemMemoryStatus {
        switch systemMemoryPercentage {
        case 0..<60: return .good
        case 60..<80: return .moderate
        default: return .highPressure
        }
    }
    
    // Progress bar values (normalized for display)
    var appMemoryProgressValue: Double {
        min(max(appMemoryPercentage, 0.0), 5.0)
    }
    
    // MARK: - Private Properties
    private let performanceMonitor = PerformanceMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind performance monitor state to view model
        performanceMonitor.$isMonitoring
            .receive(on: RunLoop.main)
            .assign(to: &$isMonitoring)
        
        // Bind performance stats
        performanceMonitor.$currentStats
            .receive(on: RunLoop.main)
            .sink { [weak self] stats in
                self?.updateStats(from: stats)
            }
            .store(in: &cancellables)
    }
    
    private func updateStats(from stats: PerformanceStats) {
        cpuUsage = stats.cpuUsage
        appMemoryUsedMB = stats.appMemoryUsedMB
        appMemoryPercentage = stats.appMemoryPercentage
        systemMemoryUsedGB = stats.systemMemoryUsedMB / 1024.0
        systemMemoryPercentage = stats.systemMemoryPercentage
        lastUpdateTime = stats.timestamp
    }
    
    // MARK: - Public Methods
    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }
    
    func startMonitoring() {
        performanceMonitor.startMonitoring()
    }
    
    func stopMonitoring() {
        performanceMonitor.stopMonitoring()
    }
    
    func cleanup() {
        performanceMonitor.stopMonitoring()
    }
}
