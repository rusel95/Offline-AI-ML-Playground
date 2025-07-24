//
//  DownloadViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

@MainActor
class DownloadViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var activeDownloads: [ModelDownload] = []
    @Published var availableModels: [AIModel] = []
    @Published var downloadedModels: Set<String> = []
    @Published var isLoadingModels = false
    @Published var searchText = ""
    @Published var selectedProvider: Provider?
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // MARK: - Computed Properties
    var hasActiveDownloads: Bool {
        !activeDownloads.isEmpty
    }
    
    var groupedModels: [(provider: Provider, models: [AIModel])] {
        let filtered = filteredModels
        let grouped = Dictionary(grouping: filtered) { $0.provider }
        return Provider.allCases.compactMap { provider in
            guard let models = grouped[provider], !models.isEmpty else { return nil }
            return (provider, models)
        }
    }
    
    var filteredModels: [AIModel] {
        var models = availableModels
        
        // Filter by search text
        if !searchText.isEmpty {
            models = models.filter { model in
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.id.localizedCaseInsensitiveContains(searchText) ||
                model.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by selected provider
        if let provider = selectedProvider {
            models = models.filter { $0.provider == provider }
        }
        
        return models
    }
    
    var totalActiveDownloadProgress: Double {
        guard !activeDownloads.isEmpty else { return 0 }
        let totalProgress = activeDownloads.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(activeDownloads.count)
    }
    
    // MARK: - Dependencies
    private let sharedManager: SharedModelManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.sharedManager = SharedModelManager.shared
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind shared manager properties
        sharedManager.$activeDownloads
            .receive(on: DispatchQueue.main)
            .map { Array($0.values) }
            .assign(to: &$activeDownloads)
        
        sharedManager.$availableModels
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableModels)
        
        sharedManager.$downloadedModels
            .receive(on: DispatchQueue.main)
            .assign(to: &$downloadedModels)
    }
    
    private func loadInitialData() {
        Task {
            await refreshModels()
        }
    }
    
    // MARK: - Public Methods
    func refreshModels() async {
        isLoadingModels = true
        // Models are loaded automatically by SharedModelManager
        isLoadingModels = false
    }
    
    func downloadModel(_ model: AIModel) {
        Task {
            do {
                try await sharedManager.downloadModel(model)
            } catch {
                showError("Failed to download \(model.name): \(error.localizedDescription)")
            }
        }
    }
    
    func cancelDownload(_ modelId: String) {
        sharedManager.cancelDownload(modelId)
    }
    
    func deleteModel(_ model: AIModel) {
        sharedManager.deleteModel(model.id)
    }
    
    func isModelDownloaded(_ modelId: String) -> Bool {
        downloadedModels.contains(modelId)
    }
    
    func isModelDownloading(_ modelId: String) -> Bool {
        activeDownloads.contains { $0.modelId == modelId }
    }
    
    func getDownloadProgress(for modelId: String) -> ModelDownload? {
        activeDownloads.first { $0.modelId == modelId }
    }
    
    // MARK: - Private Methods
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

