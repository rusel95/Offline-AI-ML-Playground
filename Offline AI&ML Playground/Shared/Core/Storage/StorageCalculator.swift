//
//  StorageCalculator.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 08.01.2025.
//

import Foundation

/// Utility class for storage calculations
public class StorageCalculator {
    
    /// Calculate total size of files in a directory
    public static func calculateDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        var totalSize: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return 0
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    /// Get available free storage space
    public static func getAvailableStorage() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )
            if let freeSpace = systemAttributes[.systemFreeSize] as? NSNumber {
                return freeSpace.int64Value
            }
        } catch {
            print("Error getting available storage: \(error)")
        }
        return 0
    }
    
    /// Get total device storage
    public static func getTotalStorage() -> Int64 {
        do {
            let systemAttributes = try FileManager.default.attributesOfFileSystem(
                forPath: NSHomeDirectory()
            )
            if let totalSpace = systemAttributes[.systemSize] as? NSNumber {
                return totalSpace.int64Value
            }
        } catch {
            print("Error getting total storage: \(error)")
        }
        return 0
    }
    
    /// Format bytes to human-readable string
    public static func formatBytes(_ bytes: Int64, countStyle: ByteCountFormatter.CountStyle = .file) -> String {
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: countStyle)
    }
    
    /// Calculate storage used percentage
    public static func calculateStorageUsedPercentage(usedBytes: Int64) -> Double {
        let totalBytes = getTotalStorage()
        guard totalBytes > 0 else { return 0.0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
    
    /// Check if sufficient storage is available
    public static func hasSufficientStorage(requiredBytes: Int64, buffer: Double = 1.1) -> Bool {
        let availableBytes = getAvailableStorage()
        let requiredWithBuffer = Int64(Double(requiredBytes) * buffer)
        return availableBytes >= requiredWithBuffer
    }
}