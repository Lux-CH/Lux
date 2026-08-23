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
    

    private enum RouteSegment {
        case leg(leg: Leg, isFirst: Bool, isLast: Bool)
        case wait(seconds: Int)

        var weight: Int {
            switch self {
            case .leg(let leg, _, _): return leg.duration
            case .wait(let seconds): return seconds
            }
        }
    }

    private var filteredLegs: [Leg] {
        legs.filter { leg in
            if leg.mode == .walk {
                if leg.from.name == leg.to.name && leg.from.track == leg.to.track {
                    return false
                }
            }
            return true
        }
    }

    private func calculateWaitingTime(between currentLeg: Leg, and nextLeg: Leg) -> Int {
        max(0, Int(nextLeg.startTime.timeIntervalSince(currentLeg.endTime)))
    }

    private var displayedSegments: [RouteSegment] {
        var segments: [RouteSegment] = []
        for (index, leg) in filteredLegs.enumerated() {
            segments.append(.leg(leg: leg, isFirst: index == 0, isLast: index == filteredLegs.count - 1))

            let nextIndex = index + 1
            if nextIndex < filteredLegs.count {
                let waitingTime = calculateWaitingTime(between: leg, and: filteredLegs[nextIndex])
                if waitingTime > 120 {
                    segments.append(.wait(seconds: waitingTime))
                }
            }
        }
        return segments
    }
    
    private func segmentWidths(for segments: [RouteSegment], availableWidth: CGFloat) -> [CGFloat] {
        let minWidth: CGFloat = 10
        guard !segments.isEmpty, availableWidth > 0 else {
            return segments.map { _ in 0 }
        }

        guard availableWidth >= minWidth * CGFloat(segments.count) else {
            return segments.map { _ in availableWidth / CGFloat(segments.count) }
        }

        var widths = [CGFloat](repeating: 0, count: segments.count)
        var pinned = [Bool](repeating: false, count: segments.count)

        while true {
            let pinnedWidth = zip(widths, pinned).reduce(CGFloat(0)) { $0 + ($1.1 ? $1.0 : 0) }
            let flexibleWeight = zip(segments, pinned).reduce(0) { $0 + ($1.1 ? 0 : $1.0.weight) }
            let remaining = availableWidth - pinnedWidth

            guard flexibleWeight > 0 else { break }

            var changed = false
            for i in segments.indices where !pinned[i] {
                let width = remaining * CGFloat(segments[i].weight) / CGFloat(flexibleWeight)
                if width < minWidth {
                    widths[i] = minWidth
                    pinned[i] = true
                    changed = true
                } else {
                    widths[i] = width
                }
            }
            if !changed { break }
        }

        return widths
    }

    @ViewBuilder
    private func segmentView(for segment: RouteSegment) -> some View {
        switch segment {
        case .leg(let leg, let isFirst, let isLast):
            LegSegmentView(leg: leg, isFirst: isFirst, isLast: isLast)
        case .wait(let seconds):
            WaitingTimeView(seconds: seconds)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let segments = displayedSegments
            let widths = segmentWidths(for: segments, availableWidth: geometry.size.width)

            HStack(spacing: 0) {
                ForEach(segments.indices, id: \.self) { index in
                    segmentView(for: segments[index])
                        .frame(width: widths[index])
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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

    private var isTrainDetected: Bool {
        guard let line = leg.routeShortName else { return false }
        return ["RL", "IR", "RE", "IC", "EC", "EXT", "ICE", "TGV", "RJ", "SN", "R"].contains {
            line.hasPrefix($0)
        }
    }

    private var isMetro: Bool {
        leg.mode == .subway
            || ["m1", "m2"].contains((leg.routeShortName ?? "").lowercased())
    }

    private var isMainlineRail: Bool {
        (leg.mode.isMainlineRail || isTrainDetected) && !isMetro
    }

    private var isEmphasizedService: Bool {
        isMainlineRail || isMetro
    }

    private var emphasizedFillOpacity: Double {
        colorScheme == .light ? 0.7 : 0.45
    }

    private var routeNameColor: Color {
        if isEmphasizedService {
            return .white.opacity(0.85)
        }
        return getLegColor(leg, brightIt: true)
    }
    
    var body: some View {
        ZStack {
            customRoundedRectangle
                .fill(getLegColor(leg).opacity(isEmphasizedService ? emphasizedFillOpacity : 0.2))
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
                        .foregroundColor(routeNameColor)
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
