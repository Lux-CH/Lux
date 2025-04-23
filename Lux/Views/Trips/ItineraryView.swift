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
    
    init(tripId: String) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(tripId: tripId))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Chargement de l'itinéraire...")
                    .progressViewStyle(CircularProgressViewStyle())
            } else if let error = viewModel.error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Une erreur est survenue lors du chargement de l'itinéraire.")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else {
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
                    
                    ForEach(viewModel.vehicleAnnotations) { vehicle in
                        Annotation("", coordinate: vehicle.coordinate) {
                            VehicleAnnotationView(annotation: vehicle)
                        }
                    }
                }
                .mapStyle(.standard)
                .onMapCameraChange { context in
                    viewModel.updateZoomLevel(distance: context.camera.distance)
                }
            }
        }
        .task {
            await viewModel.loadItinerary()
        }
    }
}

struct RouteOverlay: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}
