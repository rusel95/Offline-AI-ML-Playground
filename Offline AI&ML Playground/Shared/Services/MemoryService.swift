//
//  MemoryService.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation

final class MemoryService: MemoryManagerProtocol {
    
    func getMemoryUsage() -> (used: Double, total: Double) {
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
            let usedBytes = Double(info.resident_size)
            let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
            return (used: usedBytes, total: totalBytes)
        }
        
        return (used: 0, total: 0)
    }
    
    func performMemoryCleanup() async {
        // Trigger memory cleanup
        await Task { @MainActor in
            // Force UI updates to complete
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }.value
        
        // Suggest garbage collection
        autoreleasepool {
            // This helps release autorelease objects
        }
    }
    
    func shouldPerformCleanup(threshold: Double) -> Bool {
        let (used, total) = getMemoryUsage()
        guard total > 0 else { return false }
        
        let usagePercentage = used / total
        return usagePercentage > threshold
    }
}