//
//  OnboardNavigationView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import LuxCom

struct OnboardNavigationView: View {
    let session: OnboardSession
    @ObservedObject var itineraryViewModel: ItineraryViewModel
    @EnvironmentObject private var disruptionManager: DisruptionManager
    let onEnd: () -> Void

    @State private var isFollowing = true
    @State private var showsOverview = false
    @State private var showsConsent = false
    @State private var showsPanel = true
    @State private var stopDestination: StopDetailDestination?
    @State private var stopSheetDetent: PresentationDetent = .height(480)
    @State private var stopSheetCompactHeight: CGFloat = 480
    @State private var connectionsTask: Task<Void, Never>?
    @State private var containerWidth: CGFloat = 390
    @State private var mapModeBeforeStop: (following: Bool, overview: Bool)?
    @State private var cardHeight: CGFloat = 0
    @State private var bannerHeight: CGFloat = 120
    @State private var compactHeight: CGFloat = 150
    @State private var detent: PresentationDetent = .height(150)
    @State private var detailPath: [String] = []
    @State private var allowsMediumDetent = false

    var body: some View {
        ZStack {
            OnboardMapView(
                session: session,
                isFollowing: $isFollowing,
                showsOverview: $showsOverview,
                topInset: bannerHeight + 12,
                bottomInset: stopDestination != nil ? stopSheetCompactHeight : compactHeight + 40,
                focusedStop: stopDestination?.place
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                OnboardInstructionBanner(session: session)
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { bannerHeight = $0 }
                    .onTapGesture { recenter() }

                if let alert = session.alert {
                    OnboardAlertToast(alert: alert) { session.dismissAlert() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(alert.id)
                }

                HStack(alignment: .top) {
                    if session.phase == .riding, let speed = session.groundSpeed, let leg = session.currentLeg {
                        OnboardSpeedometer(speed: speed, mode: leg.mode, tint: getOnboardLegColor(leg))
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                    Spacer()
                    controls
                }
                .animation(.spring(duration: 0.4), value: session.groundSpeed == nil)

                Spacer()

                if !isFollowing && !showsOverview && stopDestination == nil {
                    HStack {
                        Spacer()
                        recenterButton
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .padding(.bottom, compactHeight + 56 + cardHeight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .animation(.spring(duration: 0.4), value: session.alert)
            .animation(.spring(duration: 0.35), value: isFollowing)
            .animation(.spring(duration: 0.45), value: cardHeight)

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                if session.replan != nil || session.isReplanning {
                    ReplanCard(session: session)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if session.showsCrowdPrompt, let leg = session.currentLeg {
                    CrowdPromptCard(
                        leg: leg,
                        onAnswer: { session.reportRide(.crowd, level: $0) },
                        onDismiss: { session.dismissCrowdPrompt() }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !session.transferOptions.isEmpty {
                    TransferOptionsCard(session: session)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                }
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { cardHeight = $0 }
                Color.clear.frame(height: compactHeight + 56)
            }
            .ignoresSafeArea(edges: .bottom)
            .animation(.spring(duration: 0.45), value: session.showsCrowdPrompt)
            .animation(.spring(duration: 0.45), value: session.replan)
            .animation(.spring(duration: 0.45), value: session.isReplanning)
            .animation(.spring(duration: 0.45), value: session.transferOptions)
        }
        .onChange(of: detailPath) { _, path in
            guard path.isEmpty else { return }
            if detent == .medium {
                withAnimation(.smooth(duration: 0.3)) { detent = .height(compactHeight) }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { allowsMediumDetent = false }
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .arrived { detent = .height(compactHeight) }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .sheet(isPresented: $showsPanel) {
            NavigationStack(path: $detailPath) {
                OnboardBottomPanel(session: session, itineraryViewModel: itineraryViewModel, isExpanded: detent == .large, onEnd: end, onOpenDetail: openDisruptions) { height in
                    let compact = height.rounded()
                    guard abs(compact - compactHeight) > 1 else { return }
                    let wasCompact = detent == .height(compactHeight)
                    compactHeight = compact
                    if wasCompact { detent = .height(compact) }
                }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { _ in
                    DisruptionsListView(groups: session.disruptionGroups)
                }
            }
            .presentationDetents(allowsMediumDetent ? [.height(compactHeight), .medium, .large] : [.height(compactHeight), .large], selection: $detent)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(compactHeight)))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .sheet(isPresented: $showsConsent, onDismiss: {
                session.requestNotificationPermission()
            }) {
                OnboardConsentSheet { shares in
                    session.setSharing(shares)
                    showsConsent = false
                }
                .presentationDetents([.large])
                .presentationCornerRadius(38)
            }
        }
        .task {
            guard session.needsSharingConsent else {
                session.requestNotificationPermission()
                return
            }
            try? await Task.sleep(for: .seconds(1.2))
            showsConsent = true
        }
        .onAppear {
            if disruptionManager.hasLoaded { session.updateDisruptions(disruptionManager.disruptions) }
        }
        .onChange(of: disruptionManager.disruptions) { _, disruptions in
            if disruptionManager.hasLoaded { session.updateDisruptions(disruptions) }
        }
        .onChange(of: disruptionManager.hasLoaded) { _, loaded in
            if loaded { session.updateDisruptions(disruptionManager.disruptions) }
        }
        .onChange(of: itineraryViewModel.selectedStop) { _, stop in
            if let stop { openStopSheet(stop) }
        }
        .sheet(item: $stopDestination, onDismiss: {
            itineraryViewModel.selectedStop = nil
            connectionsTask?.cancel()
            showsPanel = true
            if let mode = mapModeBeforeStop {
                mapModeBeforeStop = nil
                withAnimation(.snappy) {
                    isFollowing = mode.following
                    showsOverview = mode.overview
                }
            }
        }) { destination in
            ItineraryStopSheet(place: destination.place, connections: destination.connections, showsGo: false, detent: $stopSheetDetent, compactHeight: $stopSheetCompactHeight) { _ in }
                .presentationDetents([.height(stopSheetCompactHeight), .large], selection: $stopSheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .height(stopSheetCompactHeight)))
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(36)
        }
    }

    private var controls: some View {
        GlassEffectGroup(spacing: 8) {
            VStack(spacing: 10) {
                controlButton(
                    systemImage: session.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    label: session.voiceEnabled ? String(localized: "Couper le guidage vocal") : String(localized: "Activer le guidage vocal")
                ) {
                    HapticFeedback.selectionChanged()
                    session.voiceEnabled.toggle()
                }

                if !OfflineRouter.shared.isOfflineActive, session.phase != .arrived || session.liveShare.isSharing {
                    liveShareButton
                }

                controlButton(
                    systemImage: showsOverview ? "location.north.line.fill" : "point.topleft.down.to.point.bottomright.curvepath.fill",
                    label: showsOverview ? String(localized: "Suivre ma position") : String(localized: "Vue d'ensemble")
                ) {
                    HapticFeedback.selectionChanged()
                    withAnimation(.snappy) {
                        showsOverview.toggle()
                        isFollowing = !showsOverview
                    }
                }
            }
        }
        .liquidGlassLightModeButtonTintOptOut()
    }

    private func controlButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.luxAccent)
                .frame(width: 45, height: 45)
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace))
                .adaptable(ios26: .glassButton, fallback: {
                    $0.background(.ultraThickMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                })
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var liveShareButton: some View {
        let share = session.liveShare
        return Menu {
            if share.status == .active {
                Section(viewersDescription(share.viewers)) {
                    Button("Partager le lien", systemImage: "square.and.arrow.up") {
                        if let url = share.url { presentShareSheet(url) }
                    }
                    Button("Arrêter le partage", systemImage: "stop.circle", role: .destructive) {
                        HapticFeedback.selectionChanged()
                        share.finish(arrived: false, session: session)
                    }
                }
            } else {
                Section("Le lien montre votre position jusqu'à votre arrivée.") {
                    Button("Partager mon trajet", systemImage: "dot.radiowaves.left.and.right", action: startLiveShare)
                }
            }
        } label: {
            ZStack {
                if share.status == .starting {
                    ProgressView()
                } else {
                    Image(systemName: share.status == .active ? "dot.radiowaves.left.and.right" : "person.wave.2.fill")
                        .font(.headline)
                        .foregroundStyle(Color.luxAccent)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: share.status == .active)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 45, height: 45)
            .contentShape(Circle())
            .adaptable(ios26: .glassButton, fallback: {
                $0.background(.ultraThickMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
            })
            .shadow(radius: 2)
            .overlay(alignment: .topTrailing) {
                if share.status == .active, share.viewers > 0 {
                    Text("\(share.viewers)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.red, in: Capsule())
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(share.status == .starting)
        .accessibilityLabel(Text(share.status == .active ? "Partage actif" : "Partager mon trajet"))
    }

    private func viewersDescription(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "Personne ne suit")
        case 1: String(localized: "Suivi par 1 personne")
        default: String(localized: "Suivi par \(count) personnes")
        }
    }

    private func startLiveShare() {
        HapticFeedback.lightImpact()
        Task {
            if let url = await session.liveShare.start(for: session) {
                presentShareSheet(url)
            } else if session.liveShare.status == .idle {
                session.showAlert(
                    OnboardAlert(
                        severity: .warning,
                        symbolName: "wifi.exclamationmark",
                        title: String(localized: "Partage impossible"),
                        message: String(localized: "Vérifiez votre connexion.")
                    ),
                    spoken: nil,
                    urgency: .notice
                )
            }
        }
    }

    private func presentShareSheet(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = top.view
        top.present(controller, animated: true)
    }

    private var recenterButton: some View {
        Button(action: recenter) {
            Label("Recentrer", systemImage: "location.north.line.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.luxAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .adaptable(ios26: .glassButton, fallback: {
                    $0.background(.ultraThickMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
                })
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
    }

    private func recenter() {
        HapticFeedback.lightImpact()
        withAnimation(.snappy) {
            showsOverview = false
            isFollowing = true
        }
    }

    private func openDisruptions() {
        guard detent == .height(compactHeight) else {
            detailPath.append("disruptions")
            return
        }
        allowsMediumDetent = true
        withAnimation(.smooth(duration: 0.3)) { detent = .medium }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            detailPath.append("disruptions")
        }
    }

    private func openStopSheet(_ place: Place) {
        HapticFeedback.impact(.soft)
        connectionsTask?.cancel()
        let riding = ridingLines(at: place)
        let destination = presentStopSheet(place)
        connectionsTask = Task {
            async let fetched = ConnectionService.shared.connections(for: place.parentId ?? place.stopId ?? "")
            try? await Task.sleep(for: .seconds(0.25))
            let lines = await fetched
            guard !Task.isCancelled, stopDestination?.id == destination.id else { return }
            var updated = destination
            updated.connections = lines.filter { !riding.contains($0.line) }
            stopDestination = updated
        }
    }

    private func ridingLines(at place: Place) -> Set<String> {
        let ids = Set([place.stopId, place.parentId].compactMap { $0 })
        guard !ids.isEmpty else { return [] }
        return Set(session.legs.filter { leg in
            leg.isTransit && leg.allStops.contains { stop in
                [stop.stopId, stop.parentId].contains { id in id.map { ids.contains($0) } ?? false }
            }
        }.compactMap(\.routeShortName))
    }

    @discardableResult
    private func presentStopSheet(_ place: Place) -> StopDetailDestination {
        let destination = StopDetailDestination(place: place)
        stopSheetCompactHeight = ItineraryStopSheet.estimatedCompactHeight(
            for: place,
            width: containerWidth,
            hasConnections: false,
            showsGo: false
        )
        stopSheetDetent = .height(stopSheetCompactHeight)
        if mapModeBeforeStop == nil {
            mapModeBeforeStop = (isFollowing, showsOverview)
        }
        isFollowing = false
        showsOverview = false
        guard stopDestination == nil else {
            stopDestination = destination
            return destination
        }
        showsPanel = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stopDestination = destination
        }
        return destination
    }

    private func end() {
        session.stop()
        onEnd()
    }
}
