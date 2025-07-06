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

@MainActor
final class ItineraryViewModel: ObservableObject {
    // MARK: - Properties
    
    private var tripId: String
    private let zoomThreshold: CLLocationDistance = 50000
    private var legKeyFrames: [String: [VehicleVisualisation.KeyFrame]] = [:]
    private var vehicleUpdateTask: Task<Void, Never>?
    private var itineraryRefreshTask: Task<Void, Never>?
    private var osrmPolylines: [String: String] = [:]
    
    private var shouldStop = false
    // MARK: - Published Properties
    
    @Published var itinerary: Itinerary?
    @Published var position: MapCameraPosition = .automatic
    @Published var mapAnnotations: [StopAnnotation] = []
    @Published var routeOverlays: [RouteOverlay] = []
    @Published var showingIntermediateStops: Bool = true
    @Published var vehicleAnnotations: [VehicleAnnotation] = []
    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var walkingDirections: [String: [MKRoute.Step]] = [:]
    @ObservedObject var settings = Settings.shared
    
    // MARK: - Public Properties
    var currentTripId: String {
        return tripId
    }
    
    // MARK: - Initialization
    
    init(tripId: String) {
        self.tripId = tripId
    }
    
    convenience init(itinerary: Itinerary) {
        self.init(tripId: "")
        self.itinerary = itinerary
    }
    
    // MARK: - Public Methods
    
    func switchToTrip(tripId: String) async {
        guard tripId != self.tripId else { return }
        
        stopAllTasks()
        
        self.vehicleAnnotations = []
        self.tripId = tripId
        self.itinerary = nil
        self.mapAnnotations = []
        self.routeOverlays = []
        self.walkingDirections = [:]
        self.legKeyFrames = [:]
        self.osrmPolylines = [:]
        self.error = nil
        self.shouldStop = false
        
        await loadItinerary()
    }
    
    func stopAllTasks() {
        shouldStop = true
        stopItineraryRefresh()
        stopVehicleUpdates()
    }
    
    func loadItinerary() async {
        guard !shouldStop else { return }
        
        if itinerary != nil {
            await processItinerary()
            await refreshItinerary(dontActuallyFetch: true)
            isLoading = false
            startItineraryRefresh()
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            itinerary = try await getTrip(tripId: tripId)
            if itinerary != nil {
                await processItinerary()
                startItineraryRefresh()
            } else {
                error = "No itinerary data found"
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - MKDirections Methods
    func fetchWalkingDirections(for leg: Leg) async {
        guard leg.mode == .walk else { return }
        
        let legId = getLegIdentifier(leg)
        
        if walkingDirections[legId] != nil {
            return
        }
        
        let request = MKDirections.Request()
        
        let sourceCoordinate = CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon)
        let destinationCoordinate = CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon)
        
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                var steps = route.steps
                
                if steps.count > 2 {
                    steps.removeFirst() // remove "Head to.." instruction
                    steps.removeLast()  // remove "Arrive to..." instruction
                }
                
                await MainActor.run {
                    walkingDirections[legId] = steps
                }
            }
        } catch {
            print("failed to calculate walking directions for leg \(legId) !!! \(error)")
        }
    }
        
    private func startItineraryRefresh() {
        guard !tripId.isEmpty && !shouldStop else { return }
        
        stopItineraryRefresh()
        
        itineraryRefreshTask = Task {
            while !Task.isCancelled && !shouldStop {
                try? await Task.sleep(for: .seconds(10))
                
                guard !Task.isCancelled && !shouldStop else { break }
                
                await refreshItinerary()
            }
        }
    }
    
    private func stopItineraryRefresh() {
        itineraryRefreshTask?.cancel()
        itineraryRefreshTask = nil
    }
    
    private func refreshItinerary(dontActuallyFetch: Bool = false) async {
        guard !tripId.isEmpty && !shouldStop else { return }
        
        do {
            if !dontActuallyFetch {
                let newItinerary = try await getTrip(tripId: tripId)
                itinerary = newItinerary
            }
            else {
                itinerary = itinerary
            }
            
            await processItinerary(shouldCalculateMapPosition: false)
        } catch {
            print("failed to refresh! \(error.localizedDescription)")
        }
    }
    
    func updateZoomLevel(distance: CLLocationDistance) {
        showingIntermediateStops = distance < zoomThreshold
    }
    
    // MARK: - Private Methods
    private func processItinerary(shouldCalculateMapPosition: Bool = true) async {
        guard let itinerary = itinerary, !shouldStop else {
            error = "Missing itinerary data"
            return
        }
                
        if shouldCalculateMapPosition {
            await fetchOSRMPolylines(for: itinerary.legs)

            let (annotations, overlays) = createAnnotationsAndOverlays(for: itinerary)
            mapAnnotations = annotations
            routeOverlays = overlays
            calculateMapPosition()
        }
        
        if settings.fetchWalkingDirectionsUsingMKDirections {
            await fetchWalkingDirectionsForAllLegs(itinerary.legs)
        }
        
        prepareVehicleKeyframes(for: itinerary.legs)
        
        startVehicleUpdates()
    }
    
    private func fetchWalkingDirectionsForAllLegs(_ legs: [Leg]) async {
        await withTaskGroup(of: Void.self) { group in
            for leg in legs where leg.mode == .walk {
                group.addTask {
                    await self.fetchWalkingDirections(for: leg)
                }
            }
        }
    }
    
    private func fetchOSRMPolylines(for legs: [Leg]) async {
        for leg in legs {
            guard !shouldStop else { break }
            
            if settings.getPolylineWithOSRM && (leg.mode == .bus || leg.mode == .tram) {
                let legId = getLegIdentifier(leg)
                if osrmPolylines[legId] == nil {
                    await fetchOSRMPolyline(for: leg, legId: legId)
                }
            }
        }
    }
    
    private func fetchOSRMPolyline(for leg: Leg, legId: String) async {
        guard !shouldStop else { return }
        
        let stops = extractStopPoints(from: leg)
        guard stops.count >= 2 else { return }
        
        let coordinates = stops.map { "\($0.longitude),\($0.latitude)" }.joined(separator: ";")
        let urlString = "https://router.project-osrm.org/route/v1/driving/\(coordinates)?overview=full&geometries=polyline"
        
        guard let url = URL(string: urlString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OSRMResponse.self, from: data)
            
            if let route = response.routes.first,
               let geometry = route.geometry {
                osrmPolylines[legId] = geometry
            }
        } catch {
            print("Failed to fetch OSRM polyline for leg \(legId): \(error)")
        }
    }
    
    private func extractStopPoints(from leg: Leg) -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        
        // Add start point
        points.append(CLLocationCoordinate2D(latitude: leg.from.lat, longitude: leg.from.lon))
        
        // Add intermediate stops
        if let intermediateStops = leg.intermediateStops {
            for stop in intermediateStops {
                points.append(CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon))
            }
        }
        
        // Add end point
        points.append(CLLocationCoordinate2D(latitude: leg.to.lat, longitude: leg.to.lon))
        
        return points
    }
    
    private func getEffectivePolyline(for leg: Leg) -> String {
        let legId = getLegIdentifier(leg)
        return osrmPolylines[legId] ?? leg.legGeometry.points
    }
    
    private func getEffectivePolylinePrecision(for leg: Leg) -> Double {
        let legId = getLegIdentifier(leg)
        return osrmPolylines[legId] != nil ? 1e5 : 1e6
    }
    
    private func prepareVehicleKeyframes(for legs: [Leg]) {
        guard !shouldStop else { return }
        
        legKeyFrames.removeAll()
        
        for leg in legs where leg.mode != .walk && leg.mode != .bike {
            let legId = getLegIdentifier(leg)
            let polylineString = getEffectivePolyline(for: leg)
            let precision = getEffectivePolylinePrecision(for: leg)
            let keyFrames = VehicleVisualisation.calculateKeyFrames(for: leg, polylineString: polylineString, precision: precision)
            legKeyFrames[legId] = keyFrames
        }
    }
    
    func getLegIdentifier(_ leg: Leg) -> String {
        "\(leg.routeShortName ?? "")_\(leg.headsign ?? "")_\(leg.startTime.timeIntervalSince1970)"
    }
    
    private func startVehicleUpdates() {
        guard !shouldStop else { return }
        
        stopVehicleUpdates()
        
        vehicleUpdateTask = Task {
            while !Task.isCancelled && !shouldStop {
                updateVehiclePositions()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    deinit {
        shouldStop = true
        vehicleUpdateTask?.cancel()
        itineraryRefreshTask?.cancel()
        vehicleUpdateTask = nil
        itineraryRefreshTask = nil
    }
    
    private func stopVehicleUpdates() {
        vehicleUpdateTask?.cancel()
        vehicleUpdateTask = nil
    }

    private func updateVehiclePositions() {
        guard let itinerary = itinerary, !shouldStop else { return }
        
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
                routeShortName: leg.routeShortName,
                color: getLegColor(leg)
            )
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            vehicleAnnotations = newVehicleAnnotations
        }
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
        let polylineString = getEffectivePolyline(for: leg)
        let precision = getEffectivePolylinePrecision(for: leg)
        let polyline = Polyline(encodedPolyline: polylineString, precision: precision)
        
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

// MARK: - OSRM Response Models
struct OSRMResponse: Codable {
    let routes: [OSRMRoute]
}

struct OSRMRoute: Codable {
    let geometry: String?
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
