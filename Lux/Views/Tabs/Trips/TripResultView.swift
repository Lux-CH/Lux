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
    
    private var durationFormatter: DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter
    }
    
    var body: some View {
        NavigationLink(destination: EmptyView()) {
            VStack(alignment: .leading, spacing: 18) {
                // Time & duration summary
                HStack(alignment: .center) {
                    // Start & end time
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
                    
                    // Duration pill
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(durationFormatter.string(from: TimeInterval(itinerary.duration)) ?? "")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6))
                    )
                }
                
                // Journey details
                HStack(spacing: 16) {
                    // Transfers info (if applicable)
                    if itinerary.transfers > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text("\(itinerary.transfers) transfer\(itinerary.transfers > 1 ? "s" : "")")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Walking distance (placeholder - you would need to calculate this)
                    let walkingLegs = itinerary.legs.filter { $0.mode == .walk }
                    if !walkingLegs.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            // This is just an example - actual distance would come from your data
                            let totalWalkingDuration = walkingLegs.reduce(0) { $0 + $1.duration }
                            let walkingMinutes = totalWalkingDuration / 60
                            
                            Text("\(walkingMinutes) min")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.top, -8)
                
                // Time-proportional route visualization
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
                    let width = geometry.size.width * CGFloat(leg.duration) / CGFloat(totalDuration)
                    
                    LegSegmentView(leg: leg, isFirst: index == 0, isLast: index == legs.count - 1)
                        .frame(width: max(width, 20)) // Ensure minimum width for visibility
                }
            }
            .frame(height: geometry.size.height)
        }
    }
}

struct LegSegmentView: View {
    let leg: Leg
    let isFirst: Bool
    let isLast: Bool
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background segment
            Rectangle()
                .fill(getLegColor(leg))
                .cornerRadius(isFirst ? (isLast ? 12 : 12) : (isLast ? 12 : 0))
                .overlay(
                    HStack {
                        if isFirst {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .padding(.leading, 8)
                        }
                        
                        Spacer()
                        
                        if isLast {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .padding(.trailing, 8)
                        }
                    }
                )
                .overlay(
                    // Add subtle gradient overlay for depth
                    LinearGradient(
                        gradient: Gradient(
                            colors: [Color.white.opacity(0.15), Color.black.opacity(0.1)]
                        ),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .cornerRadius(isFirst ? (isLast ? 12 : 12) : (isLast ? 12 : 0))
                    .blendMode(.overlay)
                )
            
            // Mode icon or route label
            Group {
                if leg.mode == .walk {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
                        .scaleEffect(isAnimating ? 1.1 : 1)
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                isAnimating = true
                            }
                        }
                } else if let routeName = leg.routeShortName {
                    Text(routeName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
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
