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
            timelineLines
            
            stopIndicator
        }
    }
    
    @ViewBuilder
    private var timelineLines: some View {
        if !isFirstStop {
            Rectangle()
                .fill(lineColor)
                .frame(width: 3)
                .offset(y: -18)
        }
        
        if !isLastStop {
            Rectangle()
                .fill(lineColor)
                .frame(width: 3)
                .offset(y: 18)
        }
    }
    
    @ViewBuilder
    private var stopIndicator: some View {
        if isSpecialStop {
            specialStopView
        } else if isCurrentStop {
            currentStopView
        }
        else {
            standardStopView
        }
    }
    
    @ViewBuilder
    private var specialStopView: some View {
        ZStack {
            Circle()
                .fill(backgroundCircleColor)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(legColor, lineWidth: 2)
                )
            
            Image(systemName: symbolName)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(legColor)
                .fontWeight(.medium)
        }
    }
    
    @ViewBuilder
    private var currentStopView: some View {
        Circle()
            .fill(legColor)
            .frame(width: 18, height: 18)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2.5)
            )
    }
    
    @ViewBuilder
    private var standardStopView: some View {
        Circle()
            .fill(legColor)
            .frame(width: 16, height: 16)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1)
            )
    }
    
    private var isSpecialStop: Bool {
        isDepartureStop || isArrivalStop
    }
    
    private var symbolName: String {
        switch true {
        case isDepartureStop: return "arrow.down.circle.fill"
        case isArrivalStop: return "flag.circle.fill"
        case isCurrentStop: return "circle.fill"
        default: return "circle.fill"
        }
    }
    
    private var lineColor: Color {
        isCurrentStop ? .accentColor : legColor
    }
    
    private var backgroundCircleColor: Color {
        if isDepartureStop || isArrivalStop {
            return Color(.systemBackground)
        }
        return .clear
    }
}
