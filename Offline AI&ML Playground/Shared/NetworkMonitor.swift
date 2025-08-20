//
//  NetworkMonitor.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 09.08.2025.
//

import Foundation
import Network
import Combine

/// Monitors network connectivity status throughout the app
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var isExpensive = false
    @Published var isConstrained = false
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.offlineai.networkmonitor")
    private var cancellables = Set<AnyCancellable>()
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
        case none
        
        var displayName: String {
            switch self {
            case .wifi: return "Wi-Fi"
            case .cellular: return "Cellular"
            case .ethernet: return "Ethernet"
            case .unknown: return "Unknown"
            case .none: return "No Connection"
            }
        }
        
        var iconName: String {
            switch self {
            case .wifi: return "wifi"
            case .cellular: return "antenna.radiowaves.left.and.right"
            case .ethernet: return "cable.connector"
            case .unknown: return "questionmark.circle"
            case .none: return "wifi.slash"
            }
        }
    }
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        // Network monitor cleanup happens automatically
        monitor.cancel()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { @MainActor in
                self.isConnected = path.status == .satisfied
                self.isExpensive = path.isExpensive
                self.isConstrained = path.isConstrained
                
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else if path.status == .satisfied {
                    self.connectionType = .unknown
                } else {
                    self.connectionType = .none
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    
    /// Check if download should be allowed based on connection type and user preferences
    func shouldAllowDownload(requiresWiFi: Bool = false) -> (allowed: Bool, reason: String?) {
        guard isConnected else {
            return (false, "No internet connection available")
        }
        
        if requiresWiFi && connectionType == .cellular {
            return (false, "Download requires Wi-Fi connection")
        }
        
        if isConstrained {
            return (false, "Network connection is constrained")
        }
        
        return (true, nil)
    }
}