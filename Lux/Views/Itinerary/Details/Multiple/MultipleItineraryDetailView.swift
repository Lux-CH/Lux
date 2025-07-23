//
//  MultipleItineraryDetailView.swift
//  Lux
//
//  Created by Constantin Clerc on 12.05.2025.
//

import SwiftUI
import LuxCom
import MapKit

struct MultipleItineraryDetailView: View {
    @State var itinerary: Itinerary
    @State private var expandedLegIds: Set<String> = []
    @State private var showingTightConnectionAlert = false
    @State private var selectedTightConnection: (from: String, to: String)?
    let viewModel: ItineraryViewModel
    
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
    
    private func getLegId(_ leg: Leg) -> String {
        return "\(leg.startTime.timeIntervalSince1970)-\(leg.from.name)-\(leg.to.name)"
    }
    
    private func isTightConnection(walkingLeg: Leg, legIndex: Int) -> (from: Leg, to: Leg)? {
        guard walkingLeg.mode == .walk,
              legIndex > 0,
              legIndex < itinerary.legs.count - 1 else {
            return nil
        }
        
        let previousLeg = itinerary.legs[legIndex - 1]
        let nextLeg = itinerary.legs[legIndex + 1]
        
        guard previousLeg.mode != .walk && nextLeg.mode != .walk else {
            return nil
        }
        
        let previousArrival = previousLeg.to.arrival ?? previousLeg.to.scheduledArrival ?? previousLeg.endTime
        let nextDeparture = nextLeg.from.departure ?? previousLeg.from.scheduledDeparture ?? nextLeg.startTime
        
        let totalConnectionTime = nextDeparture.timeIntervalSince(previousArrival)
        
        let walkingTime = Double(walkingLeg.duration)
        
        let bufferTime = totalConnectionTime - walkingTime
                
        if bufferTime < TimeInterval(80) {
            return (from: previousLeg, to: nextLeg)
        }
        
        return nil
    }
    
    private func getLegConnectionInfo(from fromLeg: Leg, to toLeg: Leg) -> (from: String, to: String) {
        let fromTransport = fromLeg.routeShortName ?? fromLeg.headsign ?? "le transport précédent"
        let toTransport = toLeg.routeShortName ?? toLeg.headsign ?? "le transport suivant"
        
        return (from: fromTransport, to: toTransport)
    }
    
    private func getWalkingDescription(leg: Leg, legIndex: Int) -> String {
        let fromName = leg.from.name
        let toName = leg.to.name
        
        if legIndex == 0 {
            return "Marchez vers \(toName)"
        } else if legIndex == itinerary.legs.count - 1 {
            return "Marchez vers votre destination"
        } else {
            let fromTrack = leg.from.track
            let toTrack = leg.to.track
            
            if fromName == toName {
                if let fromTrack = fromTrack, let toTrack = toTrack, fromTrack != toTrack {
                    return "Passez \(Int(fromTrack) != nil ? "de la voie" : "du quai") \(fromTrack) \(Int(toTrack) != nil ? "à la voie" : "au quai") \(toTrack)"
                } else {
                    return "Correspondance à \(fromName)"
                }
            } else {
                return "Marchez de \(fromName) à \(toName)"
            }
        }
    }
    
    private func getDirectionIcon(for step: MKRoute.Step) -> String {
        let instructions = step.instructions.lowercased()
        
        if instructions.contains("left") || instructions.contains("gauche") {
            if instructions.contains("slight") || instructions.contains("légèrement") {
                return "arrow.up.left"
            } else {
                return "arrow.turn.up.left"
            }
        } else if instructions.contains("right") || instructions.contains("droite") {
            if instructions.contains("slight") || instructions.contains("légèrement") {
                return "arrow.up.right"
            } else {
                return "arrow.turn.up.right"
            }
        } else if instructions.contains("straight") || instructions.contains("continue") ||
                    instructions.contains("droit") || instructions.contains("continuer") {
            return "arrow.up"
        } else if instructions.contains("u-turn") || instructions.contains("demi-tour") {
            return "arrow.uturn.left"
        } else if instructions.contains("roundabout") || instructions.contains("rond-point") {
            return "arrow.clockwise"
        } else if instructions.contains("merge") || instructions.contains("rejoindre") {
            return "arrow.merge"
        } else {
            return "arrow.up"
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
    
    private func getInstructionText(for step: MKRoute.Step) -> String {
        if !step.instructions.isEmpty {
            return step.instructions
        }
        
        return "Continuer sur \(formatDistance(step.distance))"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TripResultView(itinerary: itinerary, dontGoToView: true)
                .padding(.top, 30)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(itinerary.legs.enumerated()), id: \.element.legGeometry.points) { legIndex, leg in
                        if leg.mode != .walk {
                            // Transit leg
                            LegHeaderView(leg: leg, legColor: getLegColor(leg), isSingle: false, nextStop: nil)
                                .padding(.horizontal, 20)
                                .padding(.top, 25)
                                .padding(.bottom, 15)
                            
                            Divider()
                                .padding(.horizontal, 20)
                            
                            ItinerarySheetDetailStopsContentView(
                                stops: calculateUpcomingStops(leg: leg),
                                legColor: getLegColor(leg),
                                fromStop: leg.from,
                                toStop: leg.to,
                                isMultipleLeg: true
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 10)
                        } else {
                            // Walking leg
                            let legId = getLegId(leg)
                            let isExpanded = expandedLegIds.contains(legId)
                            let walkingSteps = viewModel.walkingDirections[viewModel.getLegIdentifier(leg)] ?? []
                            let tightConnectionLegs = isTightConnection(walkingLeg: leg, legIndex: legIndex)
                            let walkingDescription = getWalkingDescription(leg: leg, legIndex: legIndex)
                            
                            VStack(spacing: 0) {
                                HStack(alignment: .center, spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        
                                        Image(systemName: leg.from.name != leg.to.name ? "figure.walk" : "arrow.left.arrow.right")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(walkingDescription)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                            
                                            if let legs = tightConnectionLegs {
                                                Button(action: {
                                                    selectedTightConnection = getLegConnectionInfo(from: legs.from, to: legs.to)
                                                    showingTightConnectionAlert = true
                                                }) {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(.red)
                                                        .font(.system(size: 14))
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Label(formatDistance(leg.distance ?? 0), systemImage: "location")
                                                .labelStyle(CustomLabel(spacing: 4))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text("•")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            
                                            Label("\(leg.duration / 60) min", systemImage: "clock")
                                                .labelStyle(CustomLabel(spacing: 4))
                                                .font(.caption)
                                                .foregroundColor(tightConnectionLegs != nil ? .red : .secondary)
                                            
                                            if let track = leg.to.track, leg.from.name != leg.to.name {
                                                Text("•")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                                Label(getTrackType(track), systemImage: "train.side.front.car")
                                                    .labelStyle(CustomLabel(spacing: 4))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                            } else if tightConnectionLegs != nil {
                                                Text("-")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                                Text("Risqué")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if !walkingSteps.isEmpty {
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                if isExpanded {
                                                    expandedLegIds.remove(legId)
                                                } else {
                                                    expandedLegIds.insert(legId)
                                                }
                                            }
                                        }) {
                                            HStack(spacing: 2) {
                                                Text(isExpanded ? "Masquer" : "Détails")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                                    .padding(.trailing, 2.5)
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 10, weight: .regular))
                                                    .foregroundColor(.blue)
                                                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
                                            }
                                            .frame(width: 75)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                
                                if isExpanded && !walkingSteps.isEmpty {
                                    VStack(spacing: 0) {
                                        ForEach(Array(walkingSteps.enumerated()), id: \.offset) { stepIndex, step in
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: getDirectionIcon(for: step))
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.blue)
                                                    .clipShape(Circle())
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(getInstructionText(for: step))
                                                        .font(.subheadline)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    if step.distance > 0 {
                                                        Text(formatDistance(step.distance))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 20)
                                            
                                            if stepIndex < walkingSteps.count - 1 {
                                                Divider()
                                                    .padding(.leading, 56)
                                                    .padding(.trailing, 20)
                                            }
                                        }
                                        
                                        if leg.to.track != leg.from.track {
                                            Divider()
                                                .padding(.leading, 56)
                                                .padding(.trailing, 20)
                                            
                                            HStack(alignment: .top, spacing: 12) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.green)
                                                    .clipShape(Circle())
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(leg.to.name == "END" ? "Vous êtes arrivé à destination" : "Arrivée à \(leg.to.name)")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                    
                                                    if let track = leg.to.track, !track.isEmpty && track != "inconnu" {
                                                        Text(getTrackType(track))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                Spacer()
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 20)
                                        }
                                    }
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .scale(scale: 0.95).combined(with: .opacity)
                                    ))
                                }
                                
                                Divider()
                                    .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
                
                let itineraarySharer = ItinerarySharer()
                ShareButtonView(itinerary: itinerary, itineraarySharer: itineraarySharer)
            }
        }
        .alert("Correspondance risquée", isPresented: $showingTightConnectionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let connection = selectedTightConnection {
                Text("Attention : le temps entre le \(connection.from) et le \(connection.to) est court. Vous risqueriez de rater votre correspondance.\nPour éviter cela, augmentez le temps d'attente minimum dans les options d'itinéraire (page précédente).")
            }
        }
    }
}

// https://www.hackingwithswift.com/quick-start/swiftui/how-to-convert-a-swiftui-view-to-an-image
struct ShareButtonView: View {
    let itinerary: Itinerary
    let itineraarySharer: ItinerarySharer
    
    @State private var showingShareDialog = false
    @State private var renderedImage: Image?
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        Button(action: {
            showingShareDialog = true
        }) {
            Label("Partager", systemImage: "square.and.arrow.up")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 35)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 35)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
        .confirmationDialog("Partager l'itinéraire", isPresented: $showingShareDialog, titleVisibility: .visible) {
            if let path = itineraarySharer.getPathFromItinerary(itinerary) {
                ShareLink("Partager l'entiereté", item: path)
            }
            
            if let image = renderedImage {
                ShareLink("Partager l'aperçu en tant qu'image", item: image, preview: SharePreview("Aperçu de l'itinéraire", image: image))
            }
            
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Choisissez comment vous souhaitez partager cet itinéraire.\nLe partage de l'ensemble de l'itinéraire requiert que son receveur ait l'app.")
        }
        .onAppear {
            renderImage()
        }
        .onDisappear {
            itineraarySharer.cleanUp()
        }
    }
    
    private func renderImage() {
        let view = TripResultView(itinerary: itinerary, dontGoToView: true)
            .frame(width: 425)
            .padding(.vertical, 10)
        let renderer = ImageRenderer(content: view)
        renderer.scale = displayScale
        
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}
