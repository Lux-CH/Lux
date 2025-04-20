//
//  CustomTabBar.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: ViewMode
    @Namespace private var tabAnimation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { tab in
                TabButton(
                    tab: tab,
                    selectedTab: $selectedTab,
                    namespace: tabAnimation
                )
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
        .frame(height: 54) // Reduced height
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

struct TabButton: View {
    let tab: ViewMode
    @Binding var selectedTab: ViewMode
    var namespace: Namespace.ID
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.gray.opacity(0.8))
                    .frame(width: 30, height: 30)
            
                // Only show text for selected tab
                if selectedTab == tab {
                    Text(tab.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .transition(.opacity.combined(with: .scale))
                }
                
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 125)
            .padding(.vertical, 8)
            .background {
                if selectedTab == tab {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.1))
                        .matchedGeometryEffect(id: "TAB", in: namespace)
                }
            }
        }
    }
}
