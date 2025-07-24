//
//  StorageHeaderView.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 03.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Storage Header View
struct StorageHeaderView: View {
    @StateObject private var viewModel: StorageHeaderViewModel
    
    init(viewModel: DownloadViewModel) {
        self._viewModel = StateObject(wrappedValue: StorageHeaderViewModel(downloadViewModel: viewModel))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Local Storage")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(viewModel.formattedStorageUsed) used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            ProgressView(value: viewModel.storageProgress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
