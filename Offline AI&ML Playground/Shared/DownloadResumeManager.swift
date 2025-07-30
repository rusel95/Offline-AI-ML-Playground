//
//  DownloadResumeManager.swift
//  Offline AI&ML Playground
//
//  Created by Assistant on 07.01.2025.
//

import Foundation

/// Manages resume data for interrupted downloads
class DownloadResumeManager {
    static let shared = DownloadResumeManager()
    
    private let resumeDataDirectory: URL
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        resumeDataDirectory = documentsPath.appendingPathComponent("DownloadResumeData")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: resumeDataDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Resume Data Management
    
    /// Save resume data for a model
    func saveResumeData(_ data: Data, for modelId: String) {
        let resumeFile = resumeDataDirectory.appendingPathComponent("\(modelId).resume")
        do {
            try data.write(to: resumeFile)
            print("💾 Saved resume data for model: \(modelId)")
        } catch {
            print("❌ Failed to save resume data: \(error)")
        }
    }
    
    /// Load resume data for a model
    func loadResumeData(for modelId: String) -> Data? {
        let resumeFile = resumeDataDirectory.appendingPathComponent("\(modelId).resume")
        guard FileManager.default.fileExists(atPath: resumeFile.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: resumeFile)
            print("📂 Loaded resume data for model: \(modelId)")
            return data
        } catch {
            print("❌ Failed to load resume data: \(error)")
            return nil
        }
    }
    
    /// Delete resume data for a model
    func deleteResumeData(for modelId: String) {
        let resumeFile = resumeDataDirectory.appendingPathComponent("\(modelId).resume")
        try? FileManager.default.removeItem(at: resumeFile)
        print("🗑️ Deleted resume data for model: \(modelId)")
    }
    
    /// Check if resume data exists for a model
    func hasResumeData(for modelId: String) -> Bool {
        let resumeFile = resumeDataDirectory.appendingPathComponent("\(modelId).resume")
        return FileManager.default.fileExists(atPath: resumeFile.path)
    }
    
    /// Get all models with resume data
    func getModelsWithResumeData() -> [String] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: resumeDataDirectory, includingPropertiesForKeys: nil)
            return files.compactMap { url in
                guard url.pathExtension == "resume" else { return nil }
                return url.deletingPathExtension().lastPathComponent
            }
        } catch {
            print("❌ Failed to list resume data: \(error)")
            return []
        }
    }
    
    /// Clean up old resume data (older than 7 days)
    func cleanupOldResumeData() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: resumeDataDirectory, includingPropertiesForKeys: [.creationDateKey])
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            for file in files {
                if let attributes = try? file.resourceValues(forKeys: [.creationDateKey]),
                   let creationDate = attributes.creationDate,
                   creationDate < sevenDaysAgo {
                    try? FileManager.default.removeItem(at: file)
                    print("🧹 Cleaned up old resume data: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("❌ Failed to cleanup resume data: \(error)")
        }
    }
}