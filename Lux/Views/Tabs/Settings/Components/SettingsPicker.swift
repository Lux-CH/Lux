//
//  SettingsPicker.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI

struct SettingsPicker<SelectionValue: Hashable>: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(accentColorManager.selectedAccentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .accentColor(accentColorManager.selectedAccentColor)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
