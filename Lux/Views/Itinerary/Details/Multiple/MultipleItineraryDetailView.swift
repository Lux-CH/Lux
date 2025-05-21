//
//  MultipleItineraryDetailView.swift
//  Lux
//
//  Created by Constantin Clerc on 12.05.2025.
//

import SwiftUI
import LuxCom

struct MultipleItineraryDetailView: View {
    @State var itinerary: Itinerary
    @State private var expandedLegIds: Set<String> = []
    
    private func calculateUpcomingStops(leg: Leg) -> [Place] {
        guard let intermediateStops = leg.intermediateStops else { return [] }
        
        let now = Date()
        var allStops = [leg.from]
        allStops.append(contentsOf: intermediateStops)
        allStops.append(leg.to)
        
        return allStops.filter { stop in
            let relevantTime = stop.departure ?? stop.arrival
            return relevantTime == nil || relevantTime! >= now.addingTimeInterval(-60)
        }
    }
    
    private func calculateNextStop(leg: Leg) -> Place? {
        let now = Date()
        
        if let departureTime = leg.from.departure {
            if departureTime > now {
                return leg.from
            }
        }
        
        if let intermediateStops = leg.intermediateStops {
            for stop in intermediateStops {
                let relevantTime = stop.departure ?? stop.arrival
                if let time = relevantTime, time > now {
                    return stop
                }
            }
        }
        
        return leg.to
    }
    
    private func getLegId(_ leg: Leg) -> String {
        return "\(leg.startTime.timeIntervalSince1970)-\(leg.from.name)-\(leg.to.name)"
    }
    
    private func getDirectionIcon(_ direction: Direction) -> String {
        switch direction {
        case .depart:
            return "location.fill"
        case .hardLeft:
            return "arrow.turn.up.left"
        case .left:
            return "arrow.left"
        case .slightlyLeft:
            return "arrow.up.left"
        case .continueStraight:
            return "arrow.up"
        case .slightlyRight:
            return "arrow.up.right"
        case .right:
            return "arrow.right"
        case .hardRight:
            return "arrow.turn.up.right"
        case .circleClockwise, .circleCounterClockwise:
            return "arrow.clockwise"
        case .stairs:
            return "stairs"
        case .elevator:
            return "arrow.up.to.line.alt"
        case .uturnLeft, .uturnRight:
            return "arrow.uturn.left"
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters)) m"
        } else {
            let kilometers = meters / 1000
            return String(format: "%.1f km", kilometers)
        }
    }
    
    private func getDirectionText(_ instruction: StepInstruction) -> String {
        switch instruction.relativeDirection {
        case .depart:
            return "Départ sur \(instruction.streetName)"
        case .hardLeft:
            return "Tournez complètement à gauche sur \(instruction.streetName)"
        case .left:
            return "Tournez à gauche sur \(instruction.streetName)"
        case .slightlyLeft:
            return "Tournez légèrement à gauche sur \(instruction.streetName)"
        case .continueStraight:
            return "Continuez tout droit sur \(instruction.streetName)"
        case .slightlyRight:
            return "Tournez légèrement à droite sur \(instruction.streetName)"
        case .right:
            return "Tournez à droite sur \(instruction.streetName)"
        case .hardRight:
            return "Tournez complètement à droite sur \(instruction.streetName)"
        case .circleClockwise:
            return "Au rond-point, prenez \(instruction.exit) dans le sens horaire"
        case .circleCounterClockwise:
            return "Au rond-point, prenez \(instruction.exit) dans le sens anti-horaire"
        case .stairs:
            if instruction.toLevel > instruction.fromLevel {
                return "Montez les escaliers vers \(instruction.streetName)"
            } else {
                return "Descendez les escaliers vers \(instruction.streetName)"
            }
        case .elevator:
            if instruction.toLevel > instruction.fromLevel {
                return "Prenez l'ascenseur vers le niveau \(instruction.toLevel)"
            } else {
                return "Prenez l'ascenseur vers le niveau \(instruction.toLevel)"
            }
        case .uturnLeft:
            return "Faites demi-tour à gauche sur \(instruction.streetName)"
        case .uturnRight:
            return "Faites demi-tour à droite sur \(instruction.streetName)"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TripResultView(itinerary: itinerary, dontGoToView: true)
                .padding(.top, 30)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(itinerary.legs, id: \.legGeometry.points) { leg in
                        if leg.mode != .walk {
                            // Transit leg
                            LegHeaderView(leg: leg, legColor: getLegColor(leg), nextStop: calculateNextStop(leg: leg))
                                .padding(.horizontal, 20)
                                .padding(.top, 25)
                                .padding(.bottom, 15)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            ItinerarySheetDetailStopsContentView(
                                stops: calculateUpcomingStops(leg: leg),
                                legColor: getLegColor(leg),
                                fromStop: leg.from,
                                toStop: leg.to
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 10)
                        } else {
                            // Walking leg
                            let legId = getLegId(leg)
                            let isExpanded = expandedLegIds.contains(legId)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Marche")
                                            .font(.headline)
                                        
                                        HStack(spacing: 4) {
                                            Text(formatDistance(leg.distance ?? 0))
                                                .font(.subheadline)
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text("\(leg.duration / 60) min")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            if isExpanded {
                                                expandedLegIds.remove(legId)
                                            } else {
                                                expandedLegIds.insert(legId)
                                            }
                                        }
                                    }) {
                                        Text(isExpanded ? "Masquer" : "Itinéraire")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                        
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 15)
                                
                                if isExpanded, let instructions = leg.steps, !instructions.isEmpty {
                                    VStack(spacing: 0) {
                                        //                                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                                        //                                            HStack(alignment: .top, spacing: 10) {
                                        //                                                Image(systemName: getDirectionIcon(instruction.relativeDirection))
                                        //                                                    .foregroundColor(.blue)
                                        //                                                    .frame(width: 28, height: 28)
                                        //                                                    .background(Color.blue.opacity(0.1))
                                        //                                                    .clipShape(Circle())
                                        //
                                        //                                                VStack(alignment: .leading, spacing: 4) {
                                        //                                                    Text(getDirectionText(instruction))
                                        //                                                        .font(.subheadline)
                                        //                                                        .multilineTextAlignment(.leading)
                                        //
                                        //                                                    if instruction.distance > 0 {
                                        //                                                        Text(formatDistance(instruction.distance))
                                        //                                                            .font(.caption)
                                        //                                                            .foregroundColor(.secondary)
                                        //                                                    }
                                        //                                                }
                                        //
                                        //                                                Spacer()
                                        //                                            }
                                        //                                            .padding(.vertical, 10)
                                        //                                            .padding(.horizontal, 20)
                                        //
                                        //                                            if index < instructions.count - 1 {
                                        //                                                Divider()
                                        //                                                    .padding(.leading, 58)
                                        //                                                    .padding(.trailing, 20)
                                        //                                            }
                                        //                                        }
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "arrow.turn.up.left")
                                                .foregroundColor(.blue)
                                                .frame(width: 28, height: 28)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(Circle())
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("TODO")
                                                    .font(.subheadline)
                                                    .multilineTextAlignment(.leading)
                                                
                                                Text("0m")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 20)
                                    }
                                    .background(Color.blue.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 15)
                                }
                                
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}
