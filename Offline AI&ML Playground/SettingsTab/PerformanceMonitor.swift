//
//  PerformanceMonitor.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import Foundation
import Combine
import os.log

// MARK: - Performance Statistics
struct PerformanceStats {
    let cpuUsage: Double
    let memoryUsage: Double
    let memoryUsedMB: Double
    let memoryTotalMB: Double
    let timestamp: Date
    
    var formattedCPUUsage: String {
        String(format: "%.1f%%", cpuUsage)
    }
    
    var formattedMemoryUsage: String {
        String(format: "%.1f%%", memoryUsage)
    }
    
    var formattedMemoryUsed: String {
        String(format: "%.0f MB", memoryUsedMB)
    }
    
    var formattedMemoryTotal: String {
        String(format: "%.0f MB", memoryTotalMB)
    }
}

// MARK: - Performance Monitor
@MainActor
class PerformanceMonitor: ObservableObject {
    @Published var currentStats = PerformanceStats(
        cpuUsage: 0.0,
        memoryUsage: 0.0,
        memoryUsedMB: 0.0,
        memoryTotalMB: 0.0,
        timestamp: Date()
    )
    
    @Published var isMonitoring = false
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0 // Update every second
    private let logger = Logger(subsystem: "com.kotesku.offline-ai-ml-playground", category: "PerformanceMonitor")
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("🔄 Starting performance monitoring")
        isMonitoring = true
        
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceStats()
            }
        }
        
        // Initial update
        updatePerformanceStats()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("⏹️ Stopping performance monitoring")
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Private Methods
    
    private func updatePerformanceStats() {
        let cpuUsage = getCPUUsage()
        let (memoryUsed, memoryTotal, memoryPercentage) = getMemoryUsage()
        
        let stats = PerformanceStats(
            cpuUsage: cpuUsage,
            memoryUsage: memoryPercentage,
            memoryUsedMB: memoryUsed,
            memoryTotalMB: memoryTotal,
            timestamp: Date()
        )
        
        currentStats = stats
        
        // Log performance data for debugging
        logger.debug("📊 CPU: \(stats.formattedCPUUsage), Memory: \(stats.formattedMemoryUsage) (\(stats.formattedMemoryUsed)/\(stats.formattedMemoryTotal))")
    }
    
    // MARK: - CPU Usage
    
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            logger.error("❌ Failed to get CPU usage: kern_return_t = \(kerr)")
            return 0.0
        }
        
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        
        let threadKerr = task_threads(mach_task_self_, &threadsList, &threadsCount)
        guard threadKerr == KERN_SUCCESS, let threads = threadsList else {
            logger.error("❌ Failed to get threads list: kern_return_t = \(threadKerr)")
            return 0.0
        }
        
        var totalCPU: Double = 0.0
        
        for i in 0..<threadsCount {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let infoKerr = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            guard infoKerr == KERN_SUCCESS else { continue }
            
            let cpuUsage = (Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
            totalCPU += cpuUsage
        }
        
        // Clean up threads array - fix type casting
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.size))
        
        return min(totalCPU, 100.0) // Cap at 100%
    }
    
    // MARK: - Memory Usage
    
    private func getMemoryUsage() -> (used: Double, total: Double, percentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            logger.error("❌ Failed to get memory usage: kern_return_t = \(kerr)")
            return (0.0, 0.0, 0.0)
        }
        
        // Get physical memory info
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let residentSize = Double(info.resident_size)
        
        let usedMB = residentSize / (1024 * 1024)
        let totalMB = physicalMemory / (1024 * 1024)
        let percentage = (residentSize / physicalMemory) * 100.0
        
        return (usedMB, totalMB, percentage)
    }
}

// MARK: - System Imports
import Darwin.Mach

// Thread usage scale constant
private let TH_USAGE_SCALE: Int32 = 1000 