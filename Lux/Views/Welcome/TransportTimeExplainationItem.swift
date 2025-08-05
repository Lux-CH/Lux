//
//  TransportTimeExplainationItem.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI

struct TransportTimeExplainationItem: View {
    let time: String
    let color: Color
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            timeDisplay
            
            VStack(alignment: .leading, spacing: 3) {
                Label(title, systemImage: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
    
    private var timeDisplay: some View {
        Text(time)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 85, alignment: .center)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
    }
}
