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
    @State private var isSwitchingTrip = false
    @State private var tripSwitchTask: Task<Void, Never>?
    @State private var shouldRenderMap = true
    let fromNearby: Bool
    let itineraarySharer = ItinerarySharer()
    
    @State private var trackingMode: MapTrackingMode = .none
    @State private var onboardSession: OnboardSession?
    @AppStorage("onboardIntroSeen") private var onboardIntroSeen = false
    @State private var showsOnboardIntro = false
    @State private var showsStopPicker = false
    @State private var detailDetent: PresentationDetent

    private static func compactDetent(isSingle: Bool) -> PresentationDetent {
        guard isSingle else { return .fraction(0.225) }
        if #available(iOS 26, *) { return .fraction(0.151) }
        return .fraction(0.1)
    }

    init(tripId: String, fromNearby: Bool, otherTripOptions: [TripOption] = []) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(tripId: tripId))
        self.fromNearby = fromNearby
        self._otherItineraries = State(initialValue: otherTripOptions)
        self.isSingle = true
        self._detailDetent = State(initialValue: Self.compactDetent(isSingle: true))
    }
    
    init(itinerary: Itinerary, fromNearby: Bool) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(itinerary: itinerary))
        self.fromNearby = fromNearby
        self.isSingle = false // so basically, it's a bit sketchy, but we never load trips if it's a processed route (using trip search) ; so it's never single if itinerary is passed directly
        self._detailDetent = State(initialValue: Self.compactDetent(isSingle: false))
    }
    
    init(itinerary: Itinerary, fromNearby: Bool, destinationName: String? = nil) {
        _viewModel = StateObject(wrappedValue: ItineraryViewModel(itinerary: itinerary, destinationName: destinationName))
        self.fromNearby = fromNearby
        self.isSingle = false
        self._detailDetent = State(initialValue: Self.compactDetent(isSingle: false))
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
    
    private var sheetCornerRadius: CGFloat? {
        if #available(iOS 26, *) { return nil }
        return 38
    }

    var detents: (CGFloat, CGFloat) {
        if #available(iOS 26, *) {
            return (0.151, 112.5)
        } else {
            return (0.1, 72.5)
        }
    }
    
    private var selectableTripOptions: [TripOption] {
        var seenTripIDs = Set<String>()
        
        return otherItineraries
            .sorted { $0.startTime < $1.startTime }
            .filter { seenTripIDs.insert($0.id).inserted }
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
            } else if let onboardSession {
                OnboardNavigationView(session: onboardSession, itineraryViewModel: viewModel, onEnd: endOnboard)
                    .transition(.opacity)
            } else {
                Group {
                    if shouldRenderMap {
                        ItineraryMapView(
                            viewModel: viewModel,
                            trackingMode: $trackingMode,
                            showDetails: $showDetails,
                            isSingle: isSingle,
                            detents: detents
                        )
                    } else {
                        Color(.secondarySystemBackground)
                            .ignoresSafeArea()
                    }
                }
                .overlay(alignment: .leading) {
                    VStack(spacing: 12) {
                        GlassEffectGroup(spacing: 8) {
                            VStack(spacing: 12) {
                                Button(action: {
                                    showDetails = false
                                    dismiss()
                                }) {
                                    Image(systemName: "chevron.backward")
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 45, height: 45)
                                        .contentShape(Circle())
                                        .clipShape(Circle())
                                        .adaptable(ios26: .glassButton, fallback: {
                                            $0.background(.ultraThickMaterial, in: Circle()).overlay(
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                            )
                                        })
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    withAnimation {
                                        cycleTrackingMode()
                                    }
                                }) {
                                    Image(systemName: locationButtonIcon)
                                        .font(.headline)
                                        .foregroundColor(.accentColor)
                                        .frame(width: 45, height: 45)
                                        .contentShape(Circle())
                                        .clipShape(Circle())
                                        .adaptable(ios26: .glassButton, fallback: {
                                            $0.background(.ultraThickMaterial, in: Circle()).overlay(
                                                Circle()
                                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                            )
                                        })
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if selectableTripOptions.count > 1 {
                            Menu {
                                tripSelectionMenuContent
                            } label: {
                                tripSelectionButtonLabel
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isLoading || isSwitchingTrip)
                        }
                        
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .liquidGlassLightModeButtonTintOptOut()
                }
                .overlay(alignment: .trailing) {
                    VStack(spacing: 12) {
                        if canStartOnboard {
                            onboardButton
                        }
                        if let itinerary = viewModel.itinerary {
                            ShareButtonView(
                                itinerary: itinerary,
                                itineraarySharer: itineraarySharer,
                                compact: true,
                                showCompactSaveAction: !isSingle
                            )
                        }
                        Spacer()
                    }
                    .padding(.trailing, 16)
                    .liquidGlassLightModeButtonTintOptOut()
                }
                // my saviour !! https://www.reddit.com/r/SwiftUI/comments/18xxmod/comment/kgl7z16/?utm_source=share&utm_medium=web3x&utm_name=web3xcss
                .sheet(isPresented: $showDetails) {
                    ItineraryDetailSheet(viewModel: viewModel, itinerarySharer: itineraarySharer, isSingle: isSingle, detent: $detailDetent, compactDetent: Self.compactDetent(isSingle: isSingle))
                        .presentationDetents([Self.compactDetent(isSingle: isSingle), .medium, .large], selection: $detailDetent)
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(sheetCornerRadius)
                        .presentationBackgroundInteraction(.enabled)
                        .interactiveDismissDisabled()
                }
                .sheet(isPresented: $showsStopPicker, onDismiss: {
                    if onboardSession == nil { showDetails = true }
                }) {
                    if let tripLeg = viewModel.itinerary?.legs.first {
                        OnboardStopPickerSheet(tripLeg: tripLeg, userLocation: locationManager.location) { board, alight in
                            guard let leg = LegLiveMerger.slice(tripLeg, boardIndex: board, alightIndex: alight) else { return }
                            startOnboard(Itinerary(duration: leg.duration, startTime: leg.startTime, endTime: leg.endTime, transfers: 0, legs: [leg]))
                        }
                        .presentationDetents([.medium, .large])
                        .presentationCornerRadius(sheetCornerRadius)
                    }
                }
            }
        }
        .task {
            await viewModel.loadItinerary()
        }
        .onAppear {
            locationManager.startMonitoring()
            shouldRenderMap = true
        }
        .onChange(of: viewModel.isLoading) { _, newValue in
            if !newValue {
                if fromNearby, let userLocation = locationManager.location?.coordinate {
                    viewModel.position = .camera(MapCamera(centerCoordinate: userLocation, distance: 10000))
                }
            }
        }
        .onDisappear {
            onboardSession?.stop()
            onboardSession = nil
            locationManager.stopMonitoring()
            tripSwitchTask?.cancel()
            tripSwitchTask = nil
            isSwitchingTrip = false
            shouldRenderMap = false
            trackingMode = .none
            viewModel.stopAllTasks()
        }
    }

    private var canStartOnboard: Bool {
        viewModel.itinerary.map { OnboardSession.canStart($0) } ?? false
    }

    private var onboardButton: some View {
        Button {
            HapticFeedback.mediumImpact()
            dismissOnboardIntro()
            guard let itinerary = viewModel.itinerary else { return }
            if isSingle {
                showDetails = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showsStopPicker = true }
            } else {
                startOnboard(itinerary)
            }
        } label: {
            Image(systemName: "location.north.line.fill")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 45, height: 45)
                .contentShape(Circle())
                .adaptable(ios26: .glassButtonTintedIn(AnyShape(Circle()), .accentColor), fallback: {
                    $0.background(Color.accentColor, in: Circle())
                })
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isSingle ? "À bord" : "Démarrer"))
        .overlay(alignment: .topTrailing) {
            if showsOnboardIntro {
                OnboardIntroCallout(onDismiss: dismissOnboardIntro)
                    .fixedSize()
                    .offset(x: -57)
                    .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
            }
        }
        .task { await presentOnboardIntroIfNeeded() }
    }

    private func presentOnboardIntroIfNeeded() async {
        guard !onboardIntroSeen, !showsOnboardIntro else { return }
        try? await Task.sleep(for: .seconds(0.8))
        guard !Task.isCancelled, !onboardIntroSeen, onboardSession == nil else { return }
        HapticFeedback.notification(type: .success)
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) { showsOnboardIntro = true }
        try? await Task.sleep(for: .seconds(12))
        dismissOnboardIntro()
    }

    private func dismissOnboardIntro() {
        guard showsOnboardIntro || !onboardIntroSeen else { return }
        onboardIntroSeen = true
        withAnimation(.snappy) { showsOnboardIntro = false }
    }

    private func startOnboard(_ itinerary: Itinerary) {
        let session = OnboardSession(itinerary: itinerary, destinationName: viewModel.destinationName)
        showDetails = false
        trackingMode = .none
        withAnimation(.easeInOut(duration: 0.35)) {
            onboardSession = session
        }
        session.start()
    }

    private func endOnboard() {
        withAnimation(.easeInOut(duration: 0.35)) {
            onboardSession = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showDetails = true
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
    
    @ViewBuilder
    private var tripSelectionMenuContent: some View {
        ForEach(selectableTripOptions) { tripOption in
            if tripOption.id == viewModel.tripId {
                Button(
                    getExactTime(from: tripOption.startTime),
                    systemImage: "checkmark"
                ) { }
                .disabled(true)
            } else {
                Button(getExactTime(from: tripOption.startTime)) {
                    switchToTrip(tripOption.id)
                }
            }
        }
    }
    
    @ViewBuilder
    private var tripSelectionButtonLabel: some View {
        Group {
            if viewModel.isLoading || isSwitchingTrip {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "clock")
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
        }
        .frame(width: 45, height: 45)
        .contentShape(Circle())
        .clipShape(Circle())
        .adaptable(ios26: .glassButton, fallback: {
            $0.background(.ultraThickMaterial, in: Circle()).overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        })
        .shadow(radius: 2)
    }
    
    private func switchToTrip(_ tripId: String) {
        guard tripId != viewModel.tripId else { return }
        
        HapticFeedback.lightImpact()
        isSwitchingTrip = true
        tripSwitchTask?.cancel()
        
        tripSwitchTask = Task(priority: .userInitiated) {
            await viewModel.switchToTrip(tripId: tripId)
            
            if !Task.isCancelled {
                await MainActor.run {
                    isSwitchingTrip = false
                }
            }
        }
    }
    
    func getExactTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ItineraryMapView: View {
    @ObservedObject var viewModel: ItineraryViewModel
    @Binding var trackingMode: MapTrackingMode
    @Binding var showDetails: Bool
    let isSingle: Bool
    let detents: (CGFloat, CGFloat)
    
    @State private var position: MapCameraPosition = .automatic
    @State private var stopDetailDestination: StopDetailDestination?
    
    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(viewModel.mapAnnotations) { annotation in
                if annotation.isTerminal {
                    Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                        StopAnnotationView(
                            annotation: annotation,
                            isTerminal: true,
                            onOpenExpandedStop: { place in
                                showDetails = false
                                stopDetailDestination = StopDetailDestination(place: place)
                            },
                            showSheet: $showDetails
                        )
                    }
                } else if viewModel.showingIntermediateStops {
                    Annotation(annotation.place.name, coordinate: annotation.coordinate) {
                        StopAnnotationView(
                            annotation: annotation,
                            isTerminal: false,
                            onOpenExpandedStop: { place in
                                showDetails = false
                                stopDetailDestination = StopDetailDestination(place: place)
                            },
                            showSheet: $showDetails
                        )
                    }
                }
            }
            
            StationMapContent(content: viewModel.stationOverlay, detail: viewModel.stationDetail)

            ForEach(viewModel.routeOverlays) { overlay in
                MapPolyline(coordinates: overlay.coordinates)
                    .stroke(overlay.color, lineWidth: 4)
            }
            
            ForEach(viewModel.vehicleAnnotations) { vehicle in
                Annotation("", coordinate: vehicle.coordinate, anchor: .center) {
                    VehicleAnnotationView(annotation: vehicle)
                }
            }
            
            ForEach(viewModel.walkingAnnotations) { walking in
                Annotation("", coordinate: walking.coordinate, anchor: .center) {
                    WalkingAnnotationView()
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {}
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
        .onAppear {
            position = viewModel.position
        }
        .onChange(of: viewModel.position) { _, newValue in
            position = newValue
        }
        .onChange(of: viewModel.selectedStop) { _, newStop in
            if let stop = newStop {
                showDetails = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    stopDetailDestination = StopDetailDestination(place: stop)
                }
            }
        }
        .fullScreenCover(item: $stopDetailDestination, onDismiss: {
            showDetails = true
            viewModel.selectedStop = nil
        }) { destination in
            ItineraryStopDetailView(
                stop: destination.place
            )
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        }
    }
    
    private func disableTrackingIfNeeded() {
        if trackingMode != .none {
            withAnimation {
                trackingMode = .none
            }
        }
    }
}

struct RouteOverlay: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}
