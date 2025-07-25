//
//  ModelPickerViewModel.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 07.01.2025.
//

import SwiftUI
import Combine

@MainActor
class ModelPickerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText = ""
    @Published var selectedProvider: Provider?
    @Published var availableModels: [AIModel] = []
    @Published var isLoading = false
    @Published var shouldNavigateToDownloads = false
    
    // MARK: - Dependencies
    private let chatViewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var filteredModels: [AIModel] {
        var filtered = availableModels
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { model in
                model.name.localizedCaseInsensitiveContains(searchText) ||
                model.provider.displayName.localizedCaseInsensitiveContains(searchText) ||
                model.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Filter by selected provider
        if let provider = selectedProvider {
            filtered = filtered.filter { $0.provider == provider }
        }
        
        return filtered
    }
    
    var groupedModels: [(provider: Provider, models: [AIModel])] {
        let grouped = Dictionary(grouping: filteredModels) { $0.provider }
        return Provider.allCases.compactMap { provider in
            guard let models = grouped[provider], !models.isEmpty else { return nil }
            return (provider, models.sorted { $0.name < $1.name })
        }
    }
    
    var selectedModelId: String? {
        chatViewModel.selectedModel?.id
    }
    
    var hasNoModels: Bool {
        availableModels.isEmpty
    }
    
    var uniqueProviders: [Provider] {
        let providers = Set(availableModels.map { $0.provider })
        return Provider.allCases.filter { providers.contains($0) }
    }
    
    // MARK: - Initialization
    init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
        setupBindings()
        loadAvailableModels()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Observe changes to available models in chat view model
        chatViewModel.$selectedModel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadAvailableModels() {
        isLoading = true
        availableModels = chatViewModel.availableModels
        isLoading = false
    }
    
    func selectModel(_ model: AIModel) async {
        await chatViewModel.selectModel(model)
    }
    
    func isModelSelected(_ model: AIModel) -> Bool {
        model.id == selectedModelId
    }
    
    func clearFilters() {
        searchText = ""
        selectedProvider = nil
    }
    
    func toggleProviderFilter(_ provider: Provider) {
        if selectedProvider == provider {
            selectedProvider = nil
        } else {
            selectedProvider = provider
        }
    }
    
    func navigateToDownloads() {
        chatViewModel.shouldNavigateToDownloads = true
    }
    
    // MARK: - Formatting
    func formattedModelInfo(_ model: AIModel) -> String {
        var info = [String]()
        
        // Add size
        info.append(model.formattedSize)
        
        // Add main tag if available
        if let mainTag = model.tags.first {
            info.append(mainTag)
        }
        
        return info.joined(separator: " • ")
    }
}