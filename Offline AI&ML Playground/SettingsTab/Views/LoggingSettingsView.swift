//
//  LoggingSettingsView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 14.01.2025.
//

import SwiftUI

struct LoggingSettingsView: View {
    @State private var logFileSize: Int64 = 0
    @State private var isLoading = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Log File Info Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.secondary)
                    Text("Log File Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("File Size:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: logFileSize, countStyle: .file))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Location:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Documents/ai_responses.log")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 8)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Actions Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                    Text("Log Management")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 12) {
                    // View Logs Button
                    Button(action: viewLogs) {
                        HStack {
                            Image(systemName: "eye")
                                .foregroundStyle(.blue)
                            Text("View Log File")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Share Logs Button
                    Button(action: shareLogs) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.green)
                            Text("Share Log File")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Clear Logs Button
                    Button(action: { showingClearConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                            Text("Clear All Logs")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Info Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("About AI Response Logs")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Text("The AI Response Logger captures detailed information about your conversations with AI models, including full context, streaming responses, performance metrics, and error details. This data helps with debugging and understanding model behavior.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .onAppear {
            refreshLogFileSize()
        }
        .alert("Clear All Logs", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearLogs()
            }
        } message: {
            Text("This will permanently delete all AI response logs. This action cannot be undone.")
        }
    }
    
    // MARK: - Private Methods
    
    private func refreshLogFileSize() {
        logFileSize = AIResponseLogger.shared.getLogFileSize()
    }
    
    private func viewLogs() {
        guard let logURL = AIResponseLogger.shared.getLogFileURL() else { return }
        
        // Open the log file in the default text editor
        if UIApplication.shared.canOpenURL(logURL) {
            UIApplication.shared.open(logURL)
        }
    }
    
    private func shareLogs() {
        guard let logURL = AIResponseLogger.shared.getLogFileURL() else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [logURL],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
    }
    
    private func clearLogs() {
        AIResponseLogger.shared.clearLogs()
        refreshLogFileSize()
    }
}

#Preview {
    LoggingSettingsView()
        .padding()
}