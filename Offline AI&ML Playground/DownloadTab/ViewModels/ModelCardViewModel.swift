//
//  ModelCardViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

@MainActor
class ModelCardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isDownloaded = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadSpeed: String = ""
    @Published var showingDetailSheet = false
    @Published var selectedDetailTab = 0
    
    // MARK: - Model
    let model: AIModel
    
    // MARK: - Computed Properties
    var downloadStatus: DownloadStatus {
        if isDownloading {
            return .downloading
        } else if isDownloaded {
            return .downloaded
        } else {
            return .available
        }
    }
    
    var formattedProgress: String {
        "\(Int(downloadProgress * 100))%"
    }
    
    var memoryEstimateText: String {
        model.formattedMaxMemory
    }
    
    var storageRequiredText: String {
        model.formattedSize
    }
    
    // MARK: - Dependencies
    let downloadViewModel: DownloadViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(model: AIModel, downloadViewModel: DownloadViewModel) {
        self.model = model
        self.downloadViewModel = downloadViewModel
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Monitor download status
        downloadViewModel.$downloadedModels
            .map { [weak self] downloadedModels in
                guard let self = self else { return false }
                return downloadedModels.contains(self.model.id)
            }
            .assign(to: &$isDownloaded)
        
        // Monitor active downloads
        downloadViewModel.$activeDownloads
            .sink { [weak self] downloads in
                guard let self = self else { return }
                
                if let download = downloads.first(where: { $0.modelId == self.model.id }) {
                    self.isDownloading = true
                    self.downloadProgress = download.progress
                    self.downloadSpeed = download.formattedSpeed
                } else {
                    self.isDownloading = false
                    self.downloadProgress = 0
                    self.downloadSpeed = ""
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func downloadModel() {
        downloadViewModel.downloadModel(model)
    }
    
    func cancelDownload() {
        downloadViewModel.cancelDownload(model.id)
    }
    
    func deleteModel() {
        downloadViewModel.deleteModel(model)
    }
    
    func toggleDetailSheet() {
        showingDetailSheet.toggle()
    }
}

// MARK: - Download Status
enum DownloadStatus {
    case available
    case downloading
    case downloaded
}
