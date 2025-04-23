//
//  ItineraryViewModel.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//

import SwiftUI
import MapKit
import LuxCom
import Polyline
import Combine

@MainActor
final class ItineraryViewModel: ObservableObject {
    // MARK: - Properties
    
    private let itinerary: Itinerary
    private let zoomThreshold: CLLocationDistance = 50000
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    
    @Published var position: MapCameraPosition = .automatic
    @Published var mapAnnotations: [StopAnnotation] = []
    @Published var routeOverlays: [RouteOverlay] = []
    @Published var showingIntermediateStops: Bool = true
    
    // MARK: - Initialization
    
    init(itinerary: Itinerary) {
        self.itinerary = itinerary
    }
    
    // MARK: - Public Methods
    func setupMap() {
        Task {
            await processItinerary()
        }
    }
    
    func updateZoomLevel(distance: CLLocationDistance) {
        showingIntermediateStops = distance < zoomThreshold
    }
    
    func departureTime(for annotation: StopAnnotation) -> Date? {
        if let dep = annotation.place.departure {
            return dep
        }
        if let schedDep = annotation.place.scheduledDeparture {
            return schedDep
        }
        if let arr = annotation.place.arrival {
            return arr
        }
        if let schedArr = annotation.place.scheduledArrival {
            return schedArr
        }
        return nil
    }
    
    // MARK: - Private Methods
    private func processItinerary() async {
        let (annotations, overlays) = createAnnotationsAndOverlays()
        
        mapAnnotations = annotations
        routeOverlays = overlays
        calculateMapPosition()
    }
    
    private func createAnnotationsAndOverlays() -> (annotations: [StopAnnotation], overlays: [RouteOverlay]) {
        var annotations: [StopAnnotation] = []
        var overlays: [RouteOverlay] = []
        
        itinerary.legs.enumerated().forEach { index, leg in
            let isFirstLeg = index == 0
            let isLastLeg = index == itinerary.legs.count - 1
            let legColor = getLegColor(leg)
            
            if isFirstLeg {
                annotations.append(StopAnnotation(place: leg.from, color: legColor, isTerminal: true))
            }
            
            if isLastLeg {
                annotations.append(StopAnnotation(place: leg.to, color: legColor, isTerminal: true))
            }
            
            if let intermediateStops = leg.intermediateStops, !intermediateStops.isEmpty {
                annotations.append(contentsOf: intermediateStops.map {
                    StopAnnotation(place: $0, color: legColor, isIntermediate: true)
                })
            }
            
            if let overlay = createRouteOverlay(for: leg, withColor: legColor) {
                overlays.append(overlay)
            }
        }
        return (annotations, overlays)
    }
    
    private func getLegColor(_ leg: Leg) -> Color {
        switch leg.mode {
        case .walk: return .blue
        case .bike, .car: return .gray
        default: return leg.routeShortName
                .flatMap { LineColors.color(for: $0) } ?? .accentColor
        }
    }
    
    private func createRouteOverlay(for leg: Leg, withColor color: Color) -> RouteOverlay? {
        let polyline = Polyline(encodedPolyline: leg.legGeometry.points, precision: 1e7)
        
        guard let coordinates = polyline.coordinates, !coordinates.isEmpty else { return nil }
        
        return RouteOverlay(coordinates: coordinates, color: color)
    }
    
    private func calculateMapPosition() {
        guard !mapAnnotations.isEmpty else { return }
        
        let mapRect = mapAnnotations.reduce(into: MKMapRect.null) { rect, annotation in
            let point = MKMapPoint(annotation.coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            rect = rect.union(pointRect)
        }.union(
            routeOverlays.reduce(into: MKMapRect.null) { rect, overlay in
                overlay.coordinates.forEach {
                    let point = MKMapPoint($0)
                    let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                    rect = rect.union(pointRect)
                }
            }
        )
        
        let padding = 0.2
        position = .rect(mapRect.insetBy(dx: -mapRect.width * padding/2, dy: -mapRect.height * padding/2))
    }
}
