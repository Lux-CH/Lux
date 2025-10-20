//
//  ItineraryView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//

import SwiftUI
import MapKit
import LuxCom

struct TripOption: Identifiable, Equatable {
    let id: String
    let startTime: Date
    
    static func == (lhs: TripOption, rhs: TripOption) -> Bool {
        lhs.id == rhs.id
    }
}

enum MapTrackingMode {
    case none
    case follow
    case followWithHeading
}

struct ItineraryView: View {
    @StateObject private var viewModel: ItineraryViewModel
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showDetails: Bool = true
    @State var otherItineraries: [TripOption] = []
    @State private var isSingle: Bool
    let fromNearby: Bool
    let itineraarySharer = ItinerarySharer()
    
    @State private var trackingMode: MapTrackingMode = .none

    init(tripId: String, fromNearby: Bool, otherTripOptions: [TripOption] = []) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(tripId: tripId))
        self.fromNearby = fromNearby
        self._otherItineraries = State(initialValue: otherTripOptions)
        self.isSingle = true
    }
    
    init(itinerary: Itinerary, fromNearby: Bool) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(itinerary: itinerary))
        self.fromNearby = fromNearby
        self.isSingle = false // so basically, it's a bit sketchy, but we never load trips if it's a processed route (using trip search) ; so it's never single if itinerary is passed directly
    }
    
    var locationButtonIcon: String {
        switch trackingMode {
        case .none:
            return "location"
        case .follow:
            return "location.fill"
        case .followWithHeading:
            return "location.north.line.fill"
        }
    }
    
    var detents: (CGFloat, CGFloat) {
        if #available(iOS 26, *) {
            if #unavailable(iOS 26.1) {
                return (0.1374, 68.5)
            } else {
                return (0.1, 72.5)
            }
        } else {
            return (0.1, 72.5)
        }
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
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .mapControls {
//                    MapScaleView()
                    MapCompass()
                    
                }
                .safeAreaInset(edge: .bottom) {
                    Spacer().frame(height: isSingle ? detents.1 : 165)
                }
                .onMapCameraChange { context in
                    viewModel.updateZoomLevel(distance: context.camera.distance)
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            disableTrackingIfNeeded()
                        }
                        .simultaneously(with:
                            MagnificationGesture()
                            .onChanged { _ in
                                disableTrackingIfNeeded()
                            }
                        )
                )
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
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                                .shadow(radius: 2)
                        }
                        
                        Button(action: {
                            withAnimation {
                                cycleTrackingMode()
                            }
                        }) {
                            Image(systemName: locationButtonIcon)
                                .font(.headline)
                                .foregroundColor(.accentColor)
                                .frame(width: 45, height: 45)
                                .background(.ultraThickMaterial)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                )
                                .shadow(radius: 2)
                        }
                        
                        if otherItineraries.count > 1 {
                            Menu {
                                ForEach(otherItineraries) { tripOption in
                                    if tripOption.id == viewModel.tripId {
                                        Button(
                                            getExactTime(from: tripOption.startTime),
                                            systemImage: "checkmark"
                                        ) {}
                                    }
                                    else {
                                        Button(getExactTime(from: tripOption.startTime)) {
                                            Task {
                                                await viewModel.switchToTrip(tripId: tripOption.id)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "clock")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 45, height: 45)
                                    .background(.ultraThickMaterial)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                    )
                                    .shadow(radius: 2)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 16)
                }
                // my saviour !! https://www.reddit.com/r/SwiftUI/comments/18xxmod/comment/kgl7z16/?utm_source=share&utm_medium=web3x&utm_name=web3xcss
                .sheet(isPresented: $showDetails) {
                    ItineraryDetailSheet(viewModel: viewModel, itinerarySharer: itineraarySharer, isSingle: isSingle)
                        .presentationDetents([isSingle ? .fraction(detents.0) : .fraction(0.225), .medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(38)
                        .presentationBackgroundInteraction(.enabled)
                        .interactiveDismissDisabled()
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

    private func disableTrackingIfNeeded() {
        if trackingMode != .none {
            withAnimation {
                trackingMode = .none
            }
        }
    }
    
    private func cycleTrackingMode() {
        switch trackingMode {
        case .none:
            trackingMode = .follow
            viewModel.position = .userLocation(followsHeading: false, fallback: .automatic)
        case .follow:
            trackingMode = .followWithHeading
            viewModel.position = .userLocation(followsHeading: true, fallback: .automatic)
        case .followWithHeading:
            trackingMode = .none
            if let userLocation = locationManager.location?.coordinate {
                viewModel.position = .camera(.init(centerCoordinate: userLocation, distance: viewModel.position.camera?.distance ?? 10000))
            }
        }
    }
    
    func getExactTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
