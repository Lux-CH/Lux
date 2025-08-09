//
//  PaginationDotsView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct PaginationDotsView: View {
    let groupsCount: Int
    let currentPage: Int
    let activeDotColor: Color
    let inactiveDotColor: Color
    @Binding var animateIn: Bool
    
    var body: some View {
        Group {
            if groupsCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<min(groupsCount, 10), id: \.self) { index in
                        Circle()
                            .frame(width: 5, height: 5)
                            .scaleEffect(index == currentPage ? 1.0 : 0.8)
                            .foregroundColor(index == currentPage ? activeDotColor : inactiveDotColor)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding(.bottom, 5)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeInOut(duration: 0.4).delay(0.3), value: animateIn)
            }
        }
    }
}
