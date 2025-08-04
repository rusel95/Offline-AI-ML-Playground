//
//  MemoryManager.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation
import os

/// Singleton manager for memory monitoring and management
@MainActor
public class MemoryManager: ObservableObject {
    
    static let shared = MemoryManager()
    
    @Published public private(set) var memoryUsage: Double = 0.0
    @Published public private(set) var memoryPressure: Double = 0.0
    @Published public private(set) var isUnderMemoryPressure: Bool = false
    
    private let logger = Logger(subsystem: "com.app.aiplayground", category: "MemoryManager")
    private var monitoringTask: Task<Void, Never>?
    
    /// Memory pressure threshold (80% usage)
    private let memoryPressureThreshold: Double = 0.8
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        monitoringTask?.cancel()
    }
    
    /// Start continuous memory monitoring
    private func startMonitoring() {
        monitoringTask = Task {
            while !Task.isCancelled {
                await updateMemoryMetrics()
                
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    /// Update memory usage metrics
    private func updateMemoryMetrics() async {
        let usage = await getMemoryUsage()
        let pressure = await getMemoryPressure()
        
        await MainActor.run {
            self.memoryUsage = usage
            self.memoryPressure = pressure
            self.isUnderMemoryPressure = pressure > memoryPressureThreshold
            
            if isUnderMemoryPressure {
                logger.warning("High memory pressure detected: \(Int(pressure * 100))%")
            }
        }
    }
    
    /// Get current memory usage in GB
    public func getMemoryUsage() async -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemoryBytes = info.resident_size
            let usedMemoryGB = Double(usedMemoryBytes) / 1_073_741_824.0
            return usedMemoryGB
        }
        
        return 0.0
    }
    
    /// Get current memory pressure as percentage (0.0 to 1.0)
    public func getMemoryPressure() async -> Double {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let currentUsage = await getMemoryUsage()
        let totalMemoryGB = Double(totalMemory) / 1_073_741_824.0
        
        guard totalMemoryGB > 0 else { return 0.0 }
        
        let pressure = currentUsage / totalMemoryGB
        return min(max(pressure, 0.0), 1.0)
    }
    
    /// Perform deep memory cleanup
    public func performDeepMemoryCleanup() async {
        logger.info("Starting deep memory cleanup")
        
        for round in 1...3 {
            logger.debug("Memory cleanup round \(round)")
            
            // Force garbage collection
            autoreleasepool {
                for _ in 0..<10 {
                    _ = [Int](repeating: 0, count: 1000)
                }
            }
            
            // Wait a bit between rounds
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        logger.info("Deep memory cleanup completed")
    }
    
    /// Check if sufficient memory is available for operation
    public func hasAvailableMemory(requiredGB: Double) async -> Bool {
        let pressure = await getMemoryPressure()
        let currentUsage = await getMemoryUsage()
        let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0
        let availableGB = totalMemoryGB - currentUsage
        
        return pressure < memoryPressureThreshold && availableGB >= requiredGB
    }
    
    /// Get formatted memory usage string
    public var formattedMemoryUsage: String {
        return String(format: "%.2f GB", memoryUsage)
    }
    
    /// Get formatted memory pressure string
    public var formattedMemoryPressure: String {
        return String(format: "%.0f%%", memoryPressure * 100)
    }
}