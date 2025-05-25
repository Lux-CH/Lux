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
    var onModeChange: ((ViewMode) -> Void)
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ViewMode.allCases, id: \.self) { tab in
                if tab != .search {
                    TabButton(
                        tab: tab,
                        selectedTab: $selectedTab,
                        namespace: tabAnimation,
                        onSelect: {
                            if selectedTab != tab {
                                onModeChange(tab)
                            }
                        }
                    )
                }
            }
        }
        .padding(8)
        .background(
            Capsule()
                .fill(
                    colorScheme == .dark
                    ? Color(.secondarySystemBackground).opacity(0.7)
                    : Color.white
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    radius: 10,
                    x: 0,
                    y: 5
                )
                .overlay(
                    Capsule()
                        .stroke(
                            colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.gray.opacity(0.1),
                            lineWidth: 1
                        )
                )
        )
        .frame(height: 54)
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }
}

struct TabButton: View {
    let tab: ViewMode
    @Binding var selectedTab: ViewMode
    var namespace: Namespace.ID
    var onSelect: (() -> Void)
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: {
            onSelect()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            HStack(spacing: 4) {
                Spacer(minLength: 0)
                
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary.opacity(0.6))
                    .frame(width: 30, height: 30)
            
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
                        .fill(
                            colorScheme == .dark
                            ? Color.accentColor.opacity(0.15)
                            : Color.accentColor.opacity(0.1)
                        )
                        .matchedGeometryEffect(id: "TAB", in: namespace)
                }
            }
        }
    }
}
