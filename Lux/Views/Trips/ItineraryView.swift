//
//  ItineraryView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//

import SwiftUI
import MapKit
import LuxCom

struct ItineraryView: View {
    @StateObject private var viewModel: ItineraryViewModel
    
    init(itinerary: Itinerary) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(itinerary: itinerary))
    }
    
    var body: some View {
        Map(position: $viewModel.position) {
            ForEach(viewModel.mapAnnotations) { annotation in
                if annotation.isTerminal {
                    Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                        StopAnnotationView(annotation: annotation, isTerminal: true)
                    }
                } else if viewModel.showingIntermediateStops {
                    Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                        StopAnnotationView(annotation: annotation, isTerminal: false)
                    }
                }
            }
            
            ForEach(viewModel.routeOverlays) { overlay in
                MapPolyline(coordinates: overlay.coordinates)
                    .stroke(overlay.color, lineWidth: 4)
            }
        }
        .mapStyle(.standard)
        .task {
            viewModel.setupMap()
        }
        .onMapCameraChange { context in
            viewModel.updateZoomLevel(distance: context.camera.distance)
        }
    }
}

struct StopAnnotationView: View {
    let annotation: StopAnnotation
    let isTerminal: Bool
    
    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: isTerminal ? 16 : 10, height: isTerminal ? 16 : 10)
            .overlay {
                Circle()
                    .stroke(annotation.color, lineWidth: isTerminal ? 3 : 1)
            }
    }
}

struct StopAnnotation: Identifiable {
    let id = UUID()
    let place: Place
    let coordinate: CLLocationCoordinate2D
    let color: Color
    let isTerminal: Bool
    let isIntermediate: Bool
    
    init(place: Place, color: Color, isTerminal: Bool = false, isIntermediate: Bool = false) {
        self.place = place
        self.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        self.color = color
        self.isTerminal = isTerminal
        self.isIntermediate = isIntermediate
    }
}

struct RouteOverlay: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}
