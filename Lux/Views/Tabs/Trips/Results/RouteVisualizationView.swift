//
//  RouteVisualizationView.swift
//  Lux
//
//  Created by Constantin Clerc on 26.07.2025.
//

import SwiftUI
import LuxCom

struct RouteVisualizationView: View {
    let legs: [Leg]
    
    private var totalDuration: Int {
        legs.reduce(0) { $0 + $1.duration } + calculateTotalWaitingTime()
    }

    private func calculateWaitingTime(between currentLeg: Leg, and nextLeg: Leg) -> Int {
        max(0, Int(nextLeg.startTime.timeIntervalSince(currentLeg.endTime)))
    }

    private func calculateTotalWaitingTime() -> Int {
        guard legs.count > 1 else { return 0 }
        
        return zip(legs, legs.dropFirst()).reduce(0) { totalWaiting, legPair in
            let (currentLeg, nextLeg) = legPair
            return totalWaiting + calculateWaitingTime(between: currentLeg, and: nextLeg)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<(legs.count * 2 - 1), id: \.self) { index in
                    if index % 2 == 0 {
                        let legIndex = index / 2
                        let leg = legs[legIndex]
                        let proportion = CGFloat(leg.duration) / CGFloat(totalDuration)
                        let calculatedWidth = geometry.size.width * proportion
                        let width = min(calculatedWidth, geometry.size.width - CGFloat(legs.count - 1) * 4)
                        
                        let finalWidth = max(width, CGFloat(10))
                        
                        LegSegmentView(
                            leg: leg,
                            isFirst: legIndex == 0,
                            isLast: legIndex == legs.count - 1
                        )
                        .frame(width: finalWidth)
                    } else {
                        let previousLegIndex = index / 2
                        let nextLegIndex = previousLegIndex + 1
                        
                        if nextLegIndex < legs.count {
                            let waitingTime = calculateWaitingTime(between: legs[previousLegIndex], and: legs[nextLegIndex])
                            
                            if waitingTime > 120 {
                                let proportion = CGFloat(waitingTime) / CGFloat(totalDuration)
                                let calculatedWidth = geometry.size.width * proportion
                                let finalWidth = max(calculatedWidth, 10)
                                
                                WaitingTimeView(seconds: waitingTime)
                                    .frame(width: finalWidth)
                            }
                        }
                    }
                }
            }
            .frame(height: geometry.size.height)
            .frame(maxWidth: geometry.size.width)
        }
    }
}

struct WaitingTimeView: View {
    let seconds: Int
    @Environment(\.colorScheme) private var colorScheme
    
    private var formattedTime: String {
        let minutes = seconds / 60
        return "\(minutes)m"
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.05 : 0.08),
                                    Color.black.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.overlay)
                )
            
            VStack(spacing: 1) {
                Image(systemName: "clock")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(formattedTime)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}

struct LegSegmentView: View {
    let leg: Leg
    let isFirst: Bool
    let isLast: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            customRoundedRectangle
                .fill(getLegColor(leg).opacity(0.2))
                .overlay(
                    customRoundedRectangle
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                                    Color.black.opacity(0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.overlay)
                )
            
            Group {
                if leg.mode == .walk {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                            .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                            .scaleEffect(isAnimating ? 1.05 : 1)
                        
                        if isFirst && isLast {
                            let distanceKm = (leg.distance ?? 0.0) / 1000.0
                            let formattedDistance = distanceKm >= 1.0 ?
                            String(format: "%.1f km", distanceKm) :
                            String(format: "%d m", Int(leg.distance ?? 0.0))
                            
                            Text(formattedDistance)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                    }
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                } else if let routeName = leg.routeShortName {
                    Text(routeName)
                        .font(.custom("NimbusSansBeckerPBla", size: 14))
                        .foregroundColor(getLegColor(leg))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 4)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                } else {
                    Image(systemName: getTransportIcon(for: leg.mode))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
            }
            .padding(.vertical, 2)
        }
    }
    
    private var customRoundedRectangle: some Shape {
        let cornerRadius: CGFloat = 12
        
        return RoundedCorner(
            topLeft: isFirst ? cornerRadius : 0,
            topRight: isLast ? cornerRadius : 0,
            bottomLeft: isFirst ? cornerRadius : 0,
            bottomRight: isLast ? cornerRadius : 0
        )
    }
    
    private func getTransportIcon(for mode: TransportationMode) -> String {
        switch mode {
        case .walk:
            return "figure.walk"
        case .bus:
            return "bus.fill"
        case .subway:
            return "tram.tunnel.fill"
        case .rail:
            return "train.side.front.car"
        case .tram:
            return "tram.fill"
        case .ferry:
            return "ferry.fill"
        default:
            return "car.fill"
        }
    }
}

struct RoundedCorner: Shape {
    var topLeft: CGFloat = 0
    var topRight: CGFloat = 0
    var bottomLeft: CGFloat = 0
    var bottomRight: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.size.width
        let height = rect.size.height
        
        path.move(to: CGPoint(x: topLeft, y: 0))
        
        path.addLine(to: CGPoint(x: width - topRight, y: 0))
        path.addArc(center: CGPoint(x: width - topRight, y: topRight),
                    radius: topRight,
                    startAngle: Angle(degrees: -90),
                    endAngle: Angle(degrees: 0),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: width, y: height - bottomRight))
        path.addArc(center: CGPoint(x: width - bottomRight, y: height - bottomRight),
                    radius: bottomRight,
                    startAngle: Angle(degrees: 0),
                    endAngle: Angle(degrees: 90),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: bottomLeft, y: height))
        path.addArc(center: CGPoint(x: bottomLeft, y: height - bottomLeft),
                    radius: bottomLeft,
                    startAngle: Angle(degrees: 90),
                    endAngle: Angle(degrees: 180),
                    clockwise: false)
        
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        path.addArc(center: CGPoint(x: topLeft, y: topLeft),
                    radius: topLeft,
                    startAngle: Angle(degrees: 180),
                    endAngle: Angle(degrees: 270),
                    clockwise: false)
        
        return path
    }
}
