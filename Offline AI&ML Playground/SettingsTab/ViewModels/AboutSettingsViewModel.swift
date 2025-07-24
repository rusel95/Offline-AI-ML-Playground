//
//  AboutSettingsViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Assistant on 07.01.2025.
//

import SwiftUI
import Combine

@MainActor
class AboutSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var appVersion: String = "Unknown"
    @Published var buildNumber: String = "Unknown"
    @Published var author: String = "Ruslan Popesku"
    
    // MARK: - Computed Properties
    var versionString: String {
        if buildNumber != "Unknown" {
            return "\(appVersion) (\(buildNumber))"
        }
        return appVersion
    }
    
    var attribution: String {
        "Made with ❤️ by \(author)"
    }
    
    // MARK: - Initialization
    init() {
        loadAppInfo()
    }
    
    // MARK: - Private Methods
    private func loadAppInfo() {
        if let info = Bundle.main.infoDictionary {
            appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
            buildNumber = info["CFBundleVersion"] as? String ?? "Unknown"
        }
    }
}