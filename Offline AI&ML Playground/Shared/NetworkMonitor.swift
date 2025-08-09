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
            Task { @MainActor in
                self?.updateConnectionStatus(path)
            }
        }
        monitor.start(queue: queue)
    }
    
    private func stopMonitoring() {
        monitor.cancel()
    }
    
    @MainActor
    private func updateConnectionStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .unknown
        } else {
            connectionType = .none
        }
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