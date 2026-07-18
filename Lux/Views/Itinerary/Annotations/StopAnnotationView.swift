//
//  StopAnnotationView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

struct StopDetailDestination: Identifiable {
    let id = UUID()
    let place: Place
}


struct StopAnnotation: Identifiable, Equatable {
    let id: String
    let place: Place
    let coordinate: CLLocationCoordinate2D
    let color: Color
    let isTerminal: Bool
    let isIntermediate: Bool
    
    static func == (lhs: StopAnnotation, rhs: StopAnnotation) -> Bool {
        return lhs.id == rhs.id &&
               lhs.place.arrival == rhs.place.arrival &&
               lhs.place.departure == rhs.place.departure &&
               lhs.place.track == rhs.place.track &&
               lhs.place.name == rhs.place.name &&
               lhs.color == rhs.color &&
               lhs.isTerminal == rhs.isTerminal &&
               lhs.isIntermediate == rhs.isIntermediate
    }
    
    init(place: Place, color: Color, isTerminal: Bool = false, isIntermediate: Bool = false) {
        var modifiedPlace = place
        switch place.name {
        case "START":
            modifiedPlace.name = String(localized: "Début")
        case "END":
            modifiedPlace.name = String(localized: "Fin")
        default:
            break
        }
        
        self.id = "\(place.stopId ?? "")_\(place.name)_\(place.lat)_\(place.lon)"
        self.place = modifiedPlace
        self.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        self.color = color
        self.isTerminal = isTerminal
        self.isIntermediate = isIntermediate
    }
}

struct StopAnnotationView: View {
    let annotation: StopAnnotation
    let isTerminal: Bool
    let onOpenExpandedStop: (Place) -> Void
    @State private var showPopover = false
    @State private var isLaunchingStopDetail = false
    @State private var connections: [String] = []
    @Binding var showSheet: Bool
    
    private let circleSize: CGFloat = 16
    private let terminalSize: CGFloat = 20
    private let intermediateSize: CGFloat = 10
    private let hitAreaSize: CGFloat = 44
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.clear
                .frame(width: hitAreaSize, height: hitAreaSize)
                .contentShape(Circle())
                .onTapGesture {
                    loadConnections()

                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isAnimating = true
                        showSheet = false
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isAnimating = false
                        showPopover = true
                    }
                }
            
            if isTerminal || annotation.isTerminal {
                Circle()
                    .fill(annotation.color.opacity(0.15))
                    .frame(width: terminalSize + 10, height: terminalSize + 10)
            }
            
            Circle()
                .fill(.white)
                .stroke(annotation.color, lineWidth: isTerminal || annotation.isTerminal ? 3 : 1)
                .frame(
                    width: getCircleSize(),
                    height: getCircleSize()
                )
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .popover(isPresented: $showPopover) {
            StopPopoverView(place: annotation.place, color: annotation.color, connections: connections, onNavigate: {
                isLaunchingStopDetail = true
                showPopover = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onOpenExpandedStop(annotation.place)
                    isLaunchingStopDetail = false
                }
            })
            .presentationCompactAdaptation(.popover)
        }
        .onChange(of: showPopover) {
            if !showPopover && !isLaunchingStopDetail {
                showSheet = true
            }
        }
    }
    
    private func getCircleSize() -> CGFloat {
        if isTerminal || annotation.isTerminal {
            return terminalSize
        } else if annotation.isIntermediate {
            return intermediateSize
        } else {
            return circleSize
        }
    }

    private func loadConnections() {
        guard let stopId = sanitizedStopId else { return }

        ConnectionService.shared.getConnections(for: stopId) { results in
            connections = results
        }
    }

    private var sanitizedStopId: String? {
        guard let stopId = annotation.place.stopId, !stopId.isEmpty else { return nil }
        return stopId.components(separatedBy: ":").first
    }

}

struct StopPopoverView: View {
    let place: Place
    let color: Color
    let connections: [String]
    let onNavigate: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        if #available(iOS 26, *) {
            return Color.clear
        } else {
            return Color(.secondarySystemBackground).opacity(0.8)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(place.name)
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                timingRows

                if let track = place.track {
                    HStack(spacing: 6) {
                        Image(systemName: "train.side.front.car")
                            .foregroundColor(color)
                        Text(getTrackType(track))
                            .fontWeight(.medium)
                    }
                }

                if !connections.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundColor(color)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(connections, id: \.self) { routeName in
                                    LinePill(line: routeName, mode: .bus, agency: nil)
                                }
                            }
                        }
                    }
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                }
            }
            .font(.subheadline)
            
            Button {
                onNavigate()
            } label: {
                HStack {
                    Text("Autres départs")
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .foregroundColor(colorScheme == .dark && color == .white ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .padding()
        .frame(minWidth: 250)
        .background(backgroundColor)
    }
    
    private func formatTime(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    @ViewBuilder
    private var timingRows: some View {
        if let arrival = place.arrival,
           let departure = place.departure,
           arrival != departure {
            timingRow(icon: "arrow.down.circle.fill", text: String(localized:"Arrivée prévue : \(formatTime(arrival))"))
            timingRow(icon: "arrow.up.circle.fill", text: String(localized:"Départ à : \(formatTime(departure))"))
        } else if let arrival = place.arrival {
            timingRow(icon: "clock", text: String(localized:"Arrivée prévue : \(formatTime(arrival))"))
        } else if let departure = place.departure {
            timingRow(icon: "clock", text: String(localized:"Départ à : \(formatTime(departure))"))
        }
    }

    @ViewBuilder
    private func timingRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .fontWeight(.medium)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}
