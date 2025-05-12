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
    
    private let tripId: String
    private let zoomThreshold: CLLocationDistance = 50000
    private var cancellables = Set<AnyCancellable>()
    private var legKeyFrames: [String: [VehicleVisualisation.KeyFrame]] = [:]
    private var vehicleUpdateTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    
    @Published var itinerary: Itinerary?
    @Published var position: MapCameraPosition = .automatic
    @Published var mapAnnotations: [StopAnnotation] = []
    @Published var routeOverlays: [RouteOverlay] = []
    @Published var showingIntermediateStops: Bool = true
    @Published var vehicleAnnotations: [VehicleAnnotation] = []
    @Published var isLoading: Bool = true
    @Published var error: String?
    
    // MARK: - Initialization
    
    init(tripId: String) {
        self.tripId = tripId
    }
    
    convenience init(itinerary: Itinerary) {
        self.init(tripId: "")
        self.itinerary = itinerary
    }
    
    // MARK: - Public Methods
    func loadItinerary() async {
        if itinerary != nil {
            await processItinerary()
            isLoading = false
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            itinerary = try await getTrip(tripId: tripId)
            if itinerary != nil {
                await processItinerary()
            } else {
                error = "No itinerary data found"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateZoomLevel(distance: CLLocationDistance) {
        showingIntermediateStops = distance < zoomThreshold
    }
    
    func departureTime(for annotation: StopAnnotation) -> Date? {
        annotation.place.departure ??
        annotation.place.scheduledDeparture ??
        annotation.place.arrival ??
        annotation.place.scheduledArrival
    }
    
    // MARK: - Private Methods
    private func processItinerary() async {
        guard let itinerary = itinerary else {
            error = "Missing itinerary data"
            return
        }
        
        let (annotations, overlays) = createAnnotationsAndOverlays(for: itinerary)
        
        mapAnnotations = annotations
        routeOverlays = overlays
        calculateMapPosition()
        
        prepareVehicleKeyframes(for: itinerary.legs)
        
        startVehicleUpdates()
    }
    
    private func prepareVehicleKeyframes(for legs: [Leg]) {
        legKeyFrames.removeAll()
        
        for leg in legs where leg.mode != .walk && leg.mode != .bike {
            let legId = getLegIdentifier(leg)
            let keyFrames = VehicleVisualisation.calculateKeyFrames(for: leg)
            legKeyFrames[legId] = keyFrames
        }
    }
    
    private func getLegIdentifier(_ leg: Leg) -> String {
        "\(leg.routeShortName ?? "")_\(leg.headsign ?? "")"
    }
    
    private func startVehicleUpdates() {
        stopVehicleUpdates()
        
        vehicleUpdateTask = Task {
            while !Task.isCancelled {
                updateVehiclePositions()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    deinit {
        let task = vehicleUpdateTask
        
        Task.detached {
            task?.cancel()
        }
        
        vehicleUpdateTask = nil
    }
    
    private func stopVehicleUpdates() {
        vehicleUpdateTask?.cancel()
        vehicleUpdateTask = nil
    }

    private func updateVehiclePositions() {
        guard let itinerary = itinerary else { return }
        
        let currentTime = Date()
        let currentTimeInterval = currentTime.timeIntervalSince1970
        
        let newVehicleAnnotations = itinerary.legs.compactMap { leg -> VehicleAnnotation? in
            guard leg.mode != .walk && leg.mode != .bike else { return nil }
            
            guard leg.startTime <= currentTime && leg.endTime >= currentTime else { return nil }
            
            let legId = getLegIdentifier(leg)
            
            guard let keyFrames = legKeyFrames[legId],
                  let position = VehicleVisualisation.interpolatePosition(
                    at: currentTimeInterval,
                    using: keyFrames
                  ) else { return nil }
            
            return VehicleAnnotation(
                id: legId,
                coordinate: position,
                mode: leg.mode,
                routeShortName: leg.routeShortName,
                color: getLegColor(leg)
            )
        }
        
        vehicleAnnotations = newVehicleAnnotations
    }
    
    private func createAnnotationsAndOverlays(for itinerary: Itinerary) -> (annotations: [StopAnnotation], overlays: [RouteOverlay]) {
        var annotations: [StopAnnotation] = []
        var overlays: [RouteOverlay] = []
        
        if let firstLeg = itinerary.legs.first {
            let firstLegColor = getLegColor(firstLeg)
            annotations.append(StopAnnotation(place: firstLeg.from, color: firstLegColor, isTerminal: true))
        }
        
        for (index, leg) in itinerary.legs.enumerated() {
            let legColor = getLegColor(leg)
            
            if let intermediateStops = leg.intermediateStops {
                for stop in intermediateStops {
                    annotations.append(StopAnnotation(place: stop, color: legColor, isIntermediate: true))
                }
            }
            
            let isLastLeg = index == itinerary.legs.count - 1
            let isTransferPoint = !isLastLeg && itinerary.legs[index + 1].mode != leg.mode
            
            annotations.append(StopAnnotation(
                place: leg.to,
                color: legColor,
                isTerminal: isLastLeg || isTransferPoint,
                isIntermediate: !isLastLeg && !isTransferPoint
            ))
            
            if let overlay = createRouteOverlay(for: leg, withColor: legColor) {
                overlays.append(overlay)
            }
        }
        
        return (removeDuplicateAnnotations(annotations), overlays)
    }

    private func removeDuplicateAnnotations(_ annotations: [StopAnnotation]) -> [StopAnnotation] {
        var uniqueAnnotations: [StopAnnotation] = []
        var seenCoordinates: [String: Int] = [:]
        
        for annotation in annotations {
            let key = "\(annotation.coordinate.latitude),\(annotation.coordinate.longitude)"
            
            if let existingIndex = seenCoordinates[key] {
                if annotation.isTerminal && !uniqueAnnotations[existingIndex].isTerminal {
                    uniqueAnnotations[existingIndex] = annotation
                }
            } else {
                uniqueAnnotations.append(annotation)
                seenCoordinates[key] = uniqueAnnotations.count - 1
            }
        }
        
        return uniqueAnnotations
    }

    
    private func createRouteOverlay(for leg: Leg, withColor color: Color) -> RouteOverlay? {
        let polyline = Polyline(encodedPolyline: leg.legGeometry.points, precision: 1e6)
        
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

func getLegColor(_ leg: Leg) -> Color {
    switch leg.mode {
    case .walk:
        return .blue
    case .bike, .car:
        return .gray
    default:
        if let routeName = leg.routeShortName,
           let color = LineColors.color(for: routeName) {
            return color
        } else if leg.mode == .rail || leg.mode == .highSpeedRail || leg.mode == .regionalRail || leg.mode == .regionalFastRail {
            return .red
        } else {
            return .accentColor
        }
    }
}
