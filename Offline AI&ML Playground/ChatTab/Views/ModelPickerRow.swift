//
//  ModelPickerRow.swift
//  Offline AI&ML Playground
//
//  Created by Ruslan Popesku on 05.07.2025.
//  Copyright © 2025 Ruslan Popesku. All rights reserved.
//

import SwiftUI

// MARK: - Model Picker Row
struct ModelPickerRow: View {
    let model: AIModel
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isVisionModel: Bool {
        model.name.lowercased().contains("mobilevit") ||
        model.name.lowercased().contains("vision") ||
        model.tags.contains("vision")
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Model icon
                ZStack {
                    Circle()
                        .fill(model.type.color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: model.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(model.type.color)
                }
                
                // Model info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if isVisionModel {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                    
                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(model.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.gray, in: Capsule())
                        
                        Text(model.type.displayName)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(model.type.color, in: Capsule())
                        
                        if isVisionModel {
                            Text("Vision")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isVisionModel)
        .opacity(isVisionModel ? 0.6 : 1.0)
    }
}
