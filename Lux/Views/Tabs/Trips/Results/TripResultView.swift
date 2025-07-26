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
    @State var dontGoToView: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
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
        if !dontGoToView {
            NavigationLink(destination:
                            ItineraryView(itinerary: itinerary, fromNearby: false)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
            ) {
                buttonContent
            }
            .buttonStyle(TripsResultBttnStyle())
            .padding(.horizontal, 16)
        }
        else {
            buttonContent
                .padding(.horizontal, 16)
        }
    }
    private var buttonContent: some View {
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
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct TripsResultBttnStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(colorScheme == .dark ?
                          Color(.systemFill).opacity(0.3) :
                          Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                        radius: configuration.isPressed ? 4 : 10,
                        x: 0,
                        y: configuration.isPressed ? 2 : 4
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

