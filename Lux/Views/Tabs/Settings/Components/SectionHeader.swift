//
//  SectionHeader.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI

struct SectionHeader: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var showInfoButton: Bool = false
    var infoAction: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(iconColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.black)
                    .textCase(.uppercase)
                    .foregroundColor(.secondary)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showInfoButton {
                Button(action: {
                    infoAction?()
                }) {
                    Image(systemName: "info.circle")
                        .font(.callout)
                        .foregroundColor(.accentColor)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
