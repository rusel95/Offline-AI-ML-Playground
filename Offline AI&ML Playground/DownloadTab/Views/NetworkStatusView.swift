//
//  NetworkStatusView.swift
//  Offline AI&ML Playground
//
//  Created by Assistant on 07.01.2025.
//

import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject var networkMonitor = NetworkMonitor.shared
    @State private var showDetails = false
    
    var body: some View {
        if !networkMonitor.isConnected {
            offlineBanner
        } else if networkMonitor.isExpensive || networkMonitor.isConstrained {
            limitedConnectionBanner
        }
    }
    
    private var offlineBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.title2)
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("You're Offline")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text("Downloads will resume when connection is restored")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white)
                        .font(.caption)
                }
            }
            .padding()
            
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Downloaded models remain available offline")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Text("Downloads will automatically resume")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("Model discovery requires internet")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.red.gradient)
        )
        .animation(.easeInOut(duration: 0.3), value: showDetails)
    }
    
    private var limitedConnectionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: networkMonitor.connectionType.iconName)
                .font(.title3)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Limited Connection")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if networkMonitor.isExpensive {
                    Text("Using cellular data - charges may apply")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if networkMonitor.isConstrained {
                    Text("Network is constrained - downloads may be slow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Connection Type Badge
struct ConnectionTypeBadge: View {
    let connectionType: NetworkMonitor.ConnectionType
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: connectionType.iconName)
                .font(.caption)
            Text(connectionType.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(badgeColor.opacity(0.15))
        )
    }
    
    private var badgeColor: Color {
        switch connectionType {
        case .wifi, .ethernet: return .green
        case .cellular: return .orange
        case .unknown: return .gray
        case .none: return .red
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        NetworkStatusView()
            .padding()
        
        ConnectionTypeBadge(connectionType: .wifi)
        ConnectionTypeBadge(connectionType: .cellular)
        ConnectionTypeBadge(connectionType: .none)
    }
}