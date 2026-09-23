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
    let onEnd: () -> Void

    @State private var isFollowing = true
    @State private var showsOverview = false
    @State private var showsConsent = false
    @State private var stopDetail: StopDetailDestination?
    @State private var bannerHeight: CGFloat = 120
    @State private var compactHeight: CGFloat = 150
    @State private var detent: PresentationDetent = .height(150)

    var body: some View {
        ZStack {
            OnboardMapView(
                session: session,
                isFollowing: $isFollowing,
                showsOverview: $showsOverview,
                topInset: bannerHeight + 12,
                bottomInset: compactHeight + 40
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

                HStack {
                    Spacer()
                    controls
                }

                Spacer()

                if !isFollowing && !showsOverview {
                    HStack {
                        recenterButton
                        Spacer()
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .padding(.bottom, compactHeight + 56)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .animation(.spring(duration: 0.4), value: session.alert)
            .animation(.spring(duration: 0.35), value: isFollowing)

            VStack {
                Spacer()
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
                }
                Color.clear.frame(height: compactHeight + 56)
            }
            .ignoresSafeArea(edges: .bottom)
            .animation(.spring(duration: 0.45), value: session.showsCrowdPrompt)
            .animation(.spring(duration: 0.45), value: session.replan)
            .animation(.spring(duration: 0.45), value: session.isReplanning)
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .arrived { detent = .height(compactHeight) }
        }
        .sheet(isPresented: .constant(true)) {
            OnboardBottomPanel(session: session, itineraryViewModel: itineraryViewModel, isExpanded: detent == .large, onEnd: end) { height in
                let compact = (height + 14).rounded()
                guard abs(compact - compactHeight) > 1 else { return }
                let wasCompact = detent == .height(compactHeight)
                compactHeight = compact
                if wasCompact { detent = .height(compact) }
            }
            .presentationDetents([.height(compactHeight), .large], selection: $detent)
            .presentationBackgroundInteraction(.enabled(upThrough: .height(compactHeight)))
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
            .fullScreenCover(item: $stopDetail, onDismiss: {
                itineraryViewModel.selectedStop = nil
            }) { destination in
                ItineraryStopDetailView(stop: destination.place)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
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
        .onChange(of: itineraryViewModel.selectedStop) { _, stop in
            if let stop { stopDetail = StopDetailDestination(place: stop) }
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
                .foregroundStyle(Color.accentColor)
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

    private var recenterButton: some View {
        Button(action: recenter) {
            Label("Recentrer", systemImage: "location.north.line.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
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

    private func end() {
        session.stop()
        onEnd()
    }
}
