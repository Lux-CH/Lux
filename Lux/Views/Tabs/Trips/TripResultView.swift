//
//  TripResultView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.05.2025.
//

import SwiftUI
import LuxCom

struct TripResultView: View {
    let itinerary: Itinerary
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private func durationFormatter(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        NavigationLink(destination: EmptyView()) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(dateFormatter.string(from: itinerary.startTime))
                            .font(.system(size: 20, weight: .bold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, -4)
                        
                        Text(dateFormatter.string(from: itinerary.endTime))
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(durationFormatter(itinerary.duration))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                            .font(.system(size: 13))
                            .foregroundColor(itinerary.transfers == 0 ? .green : .secondary)
                        
                        if itinerary.transfers > 0 {
                            Text("\(itinerary.transfers) transfer\(itinerary.transfers > 1 ? "s" : "")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        else {
                            Text("Direct")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundColor(.secondary)
                    
                    let walkingLegs = itinerary.legs.filter { $0.mode == .walk }
                    if !walkingLegs.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            let totalWalkingDuration = walkingLegs.reduce(0) { $0 + $1.duration }
                            let walkingMinutes = totalWalkingDuration / 60
                            
                            Text("\(walkingMinutes) min")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, -8)
                
                RouteVisualizationView(legs: itinerary.legs)
                    .frame(height: 48)
                    .padding(.top, 2)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: isPressed ? 4 : 10,
                        x: 0,
                        y: isPressed ? 2 : 4
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
        .padding(.horizontal, 16)
    }
}

struct RouteVisualizationView: View {
    let legs: [Leg]
    
    private var totalDuration: Int {
        legs.reduce(0) { $0 + $1.duration }
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(legs.indices, id: \.self) { index in
                    let leg = legs[index]
                    let proportion = CGFloat(leg.duration) / CGFloat(totalDuration)
                    let calculatedWidth = geometry.size.width * proportion
                    let width = min(calculatedWidth, geometry.size.width - CGFloat(legs.count - 1) * 4)
                    
                    let finalWidth = max(width, CGFloat(10))
                    
                    LegSegmentView(
                        leg: leg,
                        isFirst: index == 0,
                        isLast: index == legs.count - 1
                    )
                    .frame(width: finalWidth)
                }
            }
            .frame(height: geometry.size.height)
            .frame(maxWidth: geometry.size.width)
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
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .scaleEffect(isAnimating ? 1.05 : 1)
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
