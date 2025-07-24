//
//  StorageHeaderViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

@MainActor
class StorageHeaderViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var storageUsed: Double = 0
    @Published var freeStorage: Double = 0
    @Published var totalStorage: Double = 0
    
    // MARK: - Computed Properties
    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageUsed), countStyle: .file)
    }
    
    var storageProgress: Double {
        guard totalStorage > 0 else { return 0 }
        return storageUsed / totalStorage
    }
    
    // MARK: - Dependencies
    private let downloadViewModel: DownloadViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(downloadViewModel: DownloadViewModel) {
        self.downloadViewModel = downloadViewModel
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor storage changes from SharedModelManager via DownloadViewModel
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStorageInfo()
            }
            .store(in: &cancellables)
        
        updateStorageInfo()
    }
    
    private func updateStorageInfo() {
        // Access storage info from SharedModelManager
        let sharedManager = SharedModelManager.shared
        storageUsed = sharedManager.storageUsed
        freeStorage = sharedManager.freeStorage
        totalStorage = storageUsed + freeStorage
    }
}
