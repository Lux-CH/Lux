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

struct RouteOverlay: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}
