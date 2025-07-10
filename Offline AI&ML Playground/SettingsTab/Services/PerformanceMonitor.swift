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
    
    // App-specific memory
    let appMemoryUsedMB: Double
    let appMemoryPercentage: Double
    
    // System-wide memory
    let systemMemoryUsedMB: Double
    let systemMemoryTotalMB: Double
    let systemMemoryPercentage: Double
    
    let timestamp: Date
    
    var formattedCPUUsage: String {
        String(format: "%.1f%%", cpuUsage)
    }
    
    // App memory formatting
    var formattedAppMemoryUsed: String {
        String(format: "%.0f MB", appMemoryUsedMB)
    }
    
    var formattedAppMemoryPercentage: String {
        String(format: "%.1f%%", appMemoryPercentage)
    }
    
    // System memory formatting
    var formattedSystemMemoryUsed: String {
        String(format: "%.0f MB", systemMemoryUsedMB)
    }
    
    var formattedSystemMemoryTotal: String {
        String(format: "%.0f MB", systemMemoryTotalMB)
    }
    
    var formattedSystemMemoryPercentage: String {
        String(format: "%.1f%%", systemMemoryPercentage)
    }
}

// MARK: - Performance Monitor
@MainActor
class PerformanceMonitor: ObservableObject {
    @Published var currentStats = PerformanceStats(
        cpuUsage: 0.0,
        appMemoryUsedMB: 0.0,
        appMemoryPercentage: 0.0,
        systemMemoryUsedMB: 0.0,
        systemMemoryTotalMB: 0.0,
        systemMemoryPercentage: 0.0,
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
        let (appMemoryMB, appMemoryPercentage) = getAppMemoryUsage()
        let (systemMemoryUsedMB, systemMemoryTotalMB, systemMemoryPercentage) = getSystemMemoryUsage()
        
        let stats = PerformanceStats(
            cpuUsage: cpuUsage,
            appMemoryUsedMB: appMemoryMB,
            appMemoryPercentage: appMemoryPercentage,
            systemMemoryUsedMB: systemMemoryUsedMB,
            systemMemoryTotalMB: systemMemoryTotalMB,
            systemMemoryPercentage: systemMemoryPercentage,
            timestamp: Date()
        )
        
        currentStats = stats
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
    
    private func getAppMemoryUsage() -> (usedMB: Double, percentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            logger.error("❌ Failed to get app memory usage: kern_return_t = \(kerr)")
            return (0.0, 0.0)
        }
        
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let residentSize = Double(info.resident_size)
        
        let usedMB = residentSize / (1024 * 1024)
        let percentage = (residentSize / physicalMemory) * 100.0
        
        return (usedMB, percentage)
    }
    
    private func getSystemMemoryUsage() -> (usedMB: Double, totalMB: Double, percentage: Double) {
        // Get system memory statistics using vm_stat
        var vmStats = vm_statistics64()
        var infoCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &infoCount)
            }
        }
        
        guard result == KERN_SUCCESS else {
            logger.error("❌ Failed to get system memory statistics: kern_return_t = \(result)")
            // Fallback to basic physical memory info
            let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            let totalMB = physicalMemory / (1024 * 1024)
            return (totalMB * 0.5, totalMB, 50.0) // Estimate 50% usage
        }
        
        // Calculate memory usage from vm_statistics
        let pageSize = vm_kernel_page_size
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        // Memory in use = active + inactive + wired + compressed
        let usedPages = vmStats.active_count + vmStats.inactive_count + vmStats.wire_count + vmStats.compressor_page_count
        
        let usedMemory = Double(UInt64(usedPages) * UInt64(pageSize))
        let usedMB = usedMemory / (1024 * 1024)
        let totalMB = totalMemory / (1024 * 1024)
        let percentage = (usedMemory / totalMemory) * 100.0
        
        return (usedMB, totalMB, percentage)
    }
}

// MARK: - System Imports
import Darwin.Mach

// Thread usage scale constant
private let TH_USAGE_SCALE: Int32 = 1000 
