//
//  DataSourcePicker.swift
//  Lux
//
//  Created by Constantin Clerc on 06.01.2026.
//

import SwiftUI

struct DataSourcePicker<SelectionValue: Hashable>: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String, symbol: String, color: Color)]
    @Namespace private var animation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                ForEach(options, id: \.value) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selection = option.value
                            NotificationCenter.default.post(name: NSNotification.Name("ReloadNearbyStops"), object: nil)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(option.symbol)
                                .font(.system(size: 24))
                                .foregroundColor(isSelected(option.value) ? option.color : .secondary)
                                .scaleEffect(isSelected(option.value) ? 1.05 : 1.0)
                            
                            Text(option.label)
                                .font(.caption)
                                .fontWeight(isSelected(option.value) ? .semibold : .regular)
                                .foregroundColor(isSelected(option.value) ? option.color : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderless)
                    .background(
                        ZStack {
                            if isSelected(option.value) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(option.color.opacity(0.15))
                                    .matchedGeometryEffect(id: "dataSourceSelection", in: animation)
                            }
                        }
                    )
                }
            }
            .padding(4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func isSelected(_ value: SelectionValue) -> Bool {
        selection == value
    }
}
