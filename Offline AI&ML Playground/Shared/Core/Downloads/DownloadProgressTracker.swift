//
//  DownloadProgressTracker.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation

/// Tracks download progress and speed calculation
public class DownloadProgressTracker {
    private var samples: [(timestamp: Date, bytes: Int64)] = []
    private let sampleWindow: TimeInterval = 2.0 // Keep 2 seconds of samples
    private let speedCalculationWindow: TimeInterval = 1.0 // Calculate speed over 1 second
    
    /// Add a new bytes sample
    public func addSample(bytes: Int64) {
        let now = Date()
        samples.append((now, bytes))
        
        // Clean up old samples outside the window
        samples.removeAll { sample in
            sample.timestamp < now.addingTimeInterval(-sampleWindow)
        }
    }
    
    /// Get average download speed in bytes per second
    public func getAverageSpeed() -> Double {
        let now = Date()
        let windowStart = now.addingTimeInterval(-speedCalculationWindow)
        
        let recentSamples = samples.filter { $0.timestamp >= windowStart }
        guard !recentSamples.isEmpty else { return 0 }
        
        let totalBytes = recentSamples.map { $0.bytes }.reduce(0, +)
        let timeSpan = now.timeIntervalSince(recentSamples.first!.timestamp)
        let effectiveSpan = max(timeSpan, 0.1) // Avoid division by zero
        
        return Double(totalBytes) / effectiveSpan
    }
    
    /// Get formatted speed string
    public func getFormattedSpeed() -> String {
        let speed = getAverageSpeed()
        
        if speed < 1024 {
            return "\(Int(speed)) B/s"
        } else if speed < 1024 * 1024 {
            return "\(Int(speed / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", speed / (1024 * 1024))
        }
    }
    
    /// Estimate remaining time based on current speed
    public func estimateRemainingTime(remainingBytes: Int64) -> TimeInterval? {
        let speed = getAverageSpeed()
        guard speed > 0 else { return nil }
        
        return TimeInterval(Double(remainingBytes) / speed)
    }
    
    /// Get formatted remaining time string
    public func getFormattedRemainingTime(remainingBytes: Int64) -> String? {
        guard let remainingTime = estimateRemainingTime(remainingBytes: remainingBytes) else {
            return nil
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        
        return formatter.string(from: remainingTime)
    }
    
    /// Reset all tracking data
    public func reset() {
        samples.removeAll()
    }
}