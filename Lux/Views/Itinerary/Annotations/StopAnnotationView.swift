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
    var isSelected = false
    
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
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isAnimating = true
                    }
                    onOpenExpandedStop(annotation.place)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            isAnimating = false
                        }
                    }
                }
            
            if isSelected {
                Circle()
                    .fill(annotation.color.opacity(0.25))
                    .frame(width: 40, height: 40)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else if isTerminal || annotation.isTerminal {
                Circle()
                    .fill(annotation.color.opacity(0.15))
                    .frame(width: terminalSize + 10, height: terminalSize + 10)
            }
            
            Circle()
                .fill(isSelected ? annotation.color : .white)
                .stroke(isSelected ? .white : annotation.color, lineWidth: isSelected || isTerminal || annotation.isTerminal ? 3 : 1)
                .frame(
                    width: isSelected ? 24 : getCircleSize(),
                    height: isSelected ? 24 : getCircleSize()
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.3 : 0.2), radius: isSelected ? 4 : 2, x: 0, y: 1)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isSelected)
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
}
