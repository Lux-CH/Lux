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
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDetails: Bool = true
    let fromNearby: Bool
    
    init(tripId: String, fromNearby: Bool) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(tripId: tripId))
        self.fromNearby = fromNearby
    }
    
    init(itinerary: Itinerary, fromNearby: Bool) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(itinerary: itinerary))
        self.fromNearby = fromNearby
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
                    UserAnnotation()
                    ForEach(viewModel.mapAnnotations) { annotation in
                        if annotation.isTerminal {
                            Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                                StopAnnotationView(annotation: annotation, isTerminal: true, showSheet: $showDetails)
                            }
                        } else if viewModel.showingIntermediateStops {
                            Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                                StopAnnotationView(annotation: annotation, isTerminal: false, showSheet: $showDetails)
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
                .mapControls {
                    MapScaleView()
                    
                }
                .safeAreaInset(edge: .bottom) {
                    Spacer().frame(height: 72.5)
                }
                .onMapCameraChange { context in
                    viewModel.updateZoomLevel(distance: context.camera.distance)
                }
                .overlay(alignment: .leading) {
                    VStack(spacing: 12) {
                        Button(action: {
                            showDetails = false
                            dismiss()
                        }) {
                            Image(systemName: "chevron.backward")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                                .frame(width: 45, height: 45)
                                .background(.ultraThickMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        
                        Button(action: {
                            if let userLocation = locationManager.location?.coordinate {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    viewModel.position = .camera(MapCamera(centerCoordinate: userLocation, distance: 10000))
                                }
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                                .frame(width: 45, height: 45)
                                .background(.ultraThickMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 2)
                        }
                        Spacer()
                    }
                    .padding(.leading, 16)
                    // my saviour !! https://www.reddit.com/r/SwiftUI/comments/18xxmod/comment/kgl7z16/?utm_source=share&utm_medium=web3x&utm_name=web3xcss
                    .sheet(isPresented: $showDetails) {
                        ItineraryDetailSheet(itinerary: viewModel.itinerary)
                            .presentationDetents([viewModel.itinerary?.legs.count == 1 && viewModel.itinerary?.legs.first?.mode != .walk ? .fraction(0.1) : .fraction(0.225), .medium, .large])
                            .presentationDragIndicator(.visible)
                            .presentationCornerRadius(38)
                            .presentationBackgroundInteraction(.enabled)
                            .interactiveDismissDisabled()
                    }
                }
            }
        }
        .task {
            await viewModel.loadItinerary()
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
            if !newValue {
                if fromNearby, let userLocation = locationManager.location?.coordinate {
                    viewModel.position = .camera(MapCamera(centerCoordinate: userLocation, distance: 10000))
                }
            }
        }
        .onDisappear {
            viewModel.stopAllTasks()
        }
    }
}

//extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
//    override open func viewDidLoad() {
//        super.viewDidLoad()
//        interactivePopGestureRecognizer?.delegate = self
//    }
//    
//    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
//        return viewControllers.count > 1
//    }
//    
//    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        true
//    }
//}

struct RouteOverlay: Identifiable {
    let id = UUID()
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}
