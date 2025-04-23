//
//  ItineraryViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//

import SwiftUI
import MapKit
import LuxCom

@MainActor
class ItineraryViewModel: ObservableObject {
    private let itinerary: Itinerary
    
    @Published var position: MapCameraPosition = .automatic
    @Published var mapAnnotations: [StopAnnotation] = []
    @Published var routeOverlays: [RouteOverlay] = []
    @Published var showingIntermediateStops: Bool = true
    
    private let zoomThreshold: CLLocationDistance = 50000
    
    init(itinerary: Itinerary) {
        self.itinerary = itinerary
    }
    
    func setupMap() {
        Task {
            await processItinerary()
            calculateMapPosition()
        }
    }
    
    func updateZoomLevel(distance: CLLocationDistance) {
        showingIntermediateStops = distance < zoomThreshold
    }
    
    private func processItinerary() async {
        mapAnnotations.removeAll()
        routeOverlays.removeAll()
        
        for (index, leg) in itinerary.legs.enumerated() {
            let isFirstLeg = index == 0
            let isLastLeg = index == itinerary.legs.count - 1
            let legColor = getLegColor(leg)
            
            if isFirstLeg {
                mapAnnotations.append(StopAnnotation(
                    place: leg.from,
                    color: legColor,
                    isTerminal: true
                ))
            }
            
            if isLastLeg {
                mapAnnotations.append(StopAnnotation(
                    place: leg.to,
                    color: legColor,
                    isTerminal: true
                ))
            }
            
            if let intermediateStops = leg.intermediateStops, !intermediateStops.isEmpty {
                mapAnnotations.append(contentsOf: intermediateStops.map { stop in
                    StopAnnotation(
                        place: stop,
                        color: legColor,
                        isIntermediate: true
                    )
                })
            }
            
            createRouteOverlay(for: leg, withColor: legColor)
        }
    }
    
    private func getLegColor(_ leg: Leg) -> Color {
        switch leg.mode {
        case .walk:
            return Color.blue
        case .bike, .car:
            return Color.gray
        default:
            return leg.routeShortName
                .flatMap { LineColors.color(for: $0) }
                ?? Color.accentColor
        }
    }
    
    private func createRouteOverlay(for leg: Leg, withColor color: Color) {
        var coordinates = [CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon)]
        
        if let intermediateStops = leg.intermediateStops, !intermediateStops.isEmpty {
            coordinates.append(contentsOf: intermediateStops.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
            })
        }
        
        if leg.mode == .walk, let steps = leg.steps, !steps.isEmpty {
            // TODO steps
        }
        
        coordinates.append(CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon))
        
        guard coordinates.count >= 2 else { return }
        
        routeOverlays.append(RouteOverlay(coordinates: coordinates, color: color))
    }
    
    private func calculateMapPosition() {
        guard !mapAnnotations.isEmpty else { return }
        
        var mapRect = MKMapRect.null
        
        for annotation in mapAnnotations {
            let point = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(origin: point, size: MKMapSize(width: 0.1, height: 0.1))
            mapRect = mapRect.union(pointRect)
        }
        
        let padding = 0.2
        let paddedSize = MKMapSize(
            width: mapRect.size.width * (1 + padding),
            height: mapRect.size.height * (1 + padding)
        )
        
        let center = MKMapPoint(
            x: mapRect.midX,
            y: mapRect.midY
        )
        
        let origin = MKMapPoint(
            x: center.x - paddedSize.width / 2,
            y: center.y - paddedSize.height / 2
        )
        
        let paddedRect = MKMapRect(
            origin: origin,
            size: paddedSize
        )
        
        position = .rect(paddedRect)
    }
}
