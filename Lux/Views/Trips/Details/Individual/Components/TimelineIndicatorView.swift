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
            
            if isDepartureStop || isArrivalStop || isCurrentStop {
                Circle()
                    .fill(isCurrentStop ? Color.accentColor.opacity(0.15) : Color.clear)
                    .frame(width: 24, height: 24)
                
                Image(systemName: symbolName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(isCurrentStop ? .accentColor : legColor)
            } else {
                Circle()
                    .fill(legColor)
                    .frame(width: 16, height: 16)
            }
        }
    }
    
    private var symbolName: String {
        if isDepartureStop { return "arrow.up.circle.fill" }
        if isArrivalStop { return "flag.circle.fill" }
        return "bus.fill"
    }
}
