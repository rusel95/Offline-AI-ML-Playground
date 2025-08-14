//
//  AIResponseLogger.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 13.08.2025.
//

import Foundation
import os.log

/// Comprehensive logging system for AI model responses and interactions
public class AIResponseLogger {
    public static let shared = AIResponseLogger()
    
    private let logger = Logger(subsystem: "com.offline-ai-playground", category: "AIResponse")
    private let fileLogger: FileHandle?
    
    private init() {
        // Create log file in Documents directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logFileURL = documentsPath.appendingPathComponent("ai_responses.log")
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        fileLogger = try? FileHandle(forWritingTo: logFileURL)
        fileLogger?.seekToEndOfFile()
        
        print("📝 AIResponseLogger initialized - Log file: \(logFileURL.path)")
    }
    
    deinit {
        fileLogger?.closeFile()
    }
    
    // MARK: - Public Logging Methods
    
    /// Log the start of a conversation turn
    public func logConversationStart(userMessage: String, model: String, contextLength: Int) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = """
        
        ================== NEW CONVERSATION TURN ==================
        Timestamp: \(timestamp)
        Model: \(model)
        Context Length: \(contextLength) characters
        
        USER MESSAGE:
        \(userMessage)
        
        FULL CONTEXT SENT TO MODEL:
        """
        
        writeToLog(logEntry)
        print("🗣️ [CONVERSATION START] User: \(String(userMessage.prefix(100)))...")
    }
    
    /// Log the full context sent to the AI model
    public func logFullContext(context: String) {
        let logEntry = """
        \(context)
        
        =================== MODEL RESPONSE ===================
        """
        
        writeToLog(logEntry)
        print("📤 [FULL CONTEXT] Length: \(context.count) chars")
        print("📤 [CONTEXT PREVIEW] \(String(context.prefix(200)))...")
    }
    
    /// Log each streaming chunk from the AI model
    public func logStreamingChunk(chunk: String, accumulatedLength: Int, tokenCount: Int, tokensPerSecond: Double) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Log to file with full detail
        let logEntry = """
        [CHUNK \(timestamp)] Tokens: \(tokenCount) | Speed: \(String(format: "%.1f", tokensPerSecond)) tok/s | Total: \(accumulatedLength) chars
        CHUNK TEXT: \(chunk)
        """
        writeToLog(logEntry)
        
        // Console log (less verbose)
        if !chunk.isEmpty {
            print("🌊 [CHUNK] \(tokenCount) tokens @ \(String(format: "%.1f", tokensPerSecond)) tok/s: \"\(chunk)\"")
        }
    }
    
    /// Log the complete final response
    public func logFinalResponse(fullResponse: String, metrics: TokenMetrics, model: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = """
        
        =================== FINAL RESPONSE ===================
        Timestamp: \(timestamp)
        Model: \(model)
        Total Tokens: \(metrics.totalTokens)
        Generation Time: \(String(format: "%.2f", metrics.totalGenerationTime)) seconds
        Average Speed: \(String(format: "%.1f", metrics.averageTokensPerSecond)) tokens/second
        Average Speed: \(String(format: "%.1f", metrics.averageTokensPerSecond)) tokens/second
        Response Length: \(fullResponse.count) characters
        
        COMPLETE RESPONSE:
        \(fullResponse)
        
        =================== END RESPONSE ===================
        
        """
        
        writeToLog(logEntry)
        
        // Console log with full response
        print("✅ [FINAL RESPONSE] Model: \(model)")
        print("📊 [METRICS] \(metrics.totalTokens) tokens in \(String(format: "%.2f", metrics.totalGenerationTime))s @ \(String(format: "%.1f", metrics.averageTokensPerSecond)) tok/s")
        print("📝 [FULL RESPONSE] \(fullResponse.count) chars:")
        print("📄 FULL AI RESPONSE START 📄")
        print(fullResponse)
        print("📄 FULL AI RESPONSE END 📄")
        print("🏁 [RESPONSE END]")
    }
    
    /// Log errors during AI generation
    public func logError(error: Error, context: String, model: String?) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = """
        
        =================== ERROR ===================
        Timestamp: \(timestamp)
        Model: \(model ?? "Unknown")
        Context: \(context)
        Error: \(error.localizedDescription)
        Error Details: \(String(describing: error))
        =================== END ERROR ===================
        
        """
        
        writeToLog(logEntry)
        print("❌ [ERROR] \(context): \(error.localizedDescription)")
    }
    
    /// Log model loading events
    public func logModelLoading(model: String, stage: String, progress: Float? = nil) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let progressText = progress != nil ? " (\(Int(progress! * 100))%)" : ""
        
        let logEntry = """
        [MODEL LOADING \(timestamp)] \(model) - \(stage)\(progressText)
        """
        
        writeToLog(logEntry)
        print("🔄 [MODEL LOADING] \(model) - \(stage)\(progressText)")
    }
    
    /// Log memory and performance metrics
    public func logPerformanceMetrics(memoryUsage: Int, memoryPressure: Double, model: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = """
        [PERFORMANCE \(timestamp)] Model: \(model) | Memory: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)) | Pressure: \(String(format: "%.1f", memoryPressure * 100))%
        """
        
        writeToLog(logEntry)
        print("📊 [PERFORMANCE] Memory: \(ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)) | Pressure: \(String(format: "%.1f", memoryPressure * 100))%")
    }
    
    // MARK: - Private Methods
    
    private func writeToLog(_ message: String) {
        guard let fileLogger = fileLogger else { return }
        
        let logMessage = message + "\n"
        if let data = logMessage.data(using: .utf8) {
            fileLogger.write(data)
        }
    }
    
    // MARK: - Log Management
    
    /// Get the current log file URL
    public func getLogFileURL() -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("ai_responses.log")
    }
    
    /// Clear the log file
    public func clearLogs() {
        guard let logURL = getLogFileURL() else { return }
        
        try? "".write(to: logURL, atomically: true, encoding: .utf8)
        print("🗑️ [LOG] Cleared AI response logs")
    }
    
    /// Get log file size
    public func getLogFileSize() -> Int64 {
        guard let logURL = getLogFileURL() else { return 0 }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}