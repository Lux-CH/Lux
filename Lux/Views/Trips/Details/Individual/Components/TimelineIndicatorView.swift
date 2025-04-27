//
//  TimelineIndicatorView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI

struct TimelineIndicatorView: View {
    let legColor: Color
    let isFirstStop: Bool
    let isLastStop: Bool
    let isDepartureStop: Bool
    let isArrivalStop: Bool
    let isCurrentStop: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack(alignment: .center) {
            if !isFirstStop {
                Rectangle()
                    .fill(legColor.opacity(0.3))
                    .frame(width: 3)
                    .offset(y: -18)
            }
            
            if !isLastStop {
                Rectangle()
                    .fill(legColor.opacity(0.3))
                    .frame(width: 3)
                    .offset(y: 18)
            }
            
            ZStack {
                Circle()
                    .fill(colorScheme == .dark ? Color(.systemGray6) : .white)
                    .frame(width: isCurrentStop ? 32 : 26, height: isCurrentStop ? 32 : 26)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                
                if isDepartureStop || isArrivalStop || isCurrentStop {
                    Circle()
                        .strokeBorder(isCurrentStop ? .accentColor : legColor, lineWidth: 2.5)
                        .background(Circle().fill(isCurrentStop ? Color.accentColor.opacity(0.15) : .clear))
                        .frame(width: isCurrentStop ? 24 : 20, height: isCurrentStop ? 24 : 20)
                    
                    Image(systemName: isDepartureStop ? "arrow.up.circle.fill" :
                            isArrivalStop ? "flag.circle.fill" : "bus.fill")
                    .font(.system(size: isCurrentStop ? 12 : 10))
                    .foregroundColor(isCurrentStop ? .accentColor : legColor)
                } else {
                    Circle()
                        .fill(legColor)
                        .frame(width: 16, height: 16)
                }
            }
        }
    }
}
