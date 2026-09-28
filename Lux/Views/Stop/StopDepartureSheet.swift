//
//  StopDepartureSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 28.09.2026.
//

import SwiftUI
import LuxCom

struct StopDepartureSheet: View {
    struct Detail: Hashable {
        let symbol: String
        let text: String
    }

    let stop: SearchResult
    var track: String? = nil
    var time: Date? = nil
    var details: [Detail] = []
    var onHeaderHeight: (CGFloat) -> Void = { _ in }
    let onGo: () -> Void

    private var shownDetails: [Detail] {
        guard let track else { return details }
        return [Detail(symbol: "signpost.right", text: getTrackType(track))] + details
    }

    private var contentKey: String {
        "\(stop.id)|\(track ?? "")|\(time?.timeIntervalSince1970 ?? 0)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(2)
                    ForEach(shownDetails, id: \.self) { detail in
                        Label(detail.text, systemImage: detail.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onGo) {
                    Label("Y aller", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .contentShape(Capsule(style: .continuous))
                        .adaptable(ios26: .glassButtonTintedIn(AnyShape(Capsule(style: .continuous)), .accentColor), fallback: {
                            $0.background(Color.accentColor, in: Capsule(style: .continuous))
                        })
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 14)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeaderHeight($0) }
            Divider()
            ExpandedStopView(stop: stop, fromStops: true, maxGroupsToShow: 50, time: time, track: track)
                .contentMargins(.bottom, 30, for: .scrollContent)
                .ignoresSafeArea(.container, edges: .bottom)
                .environment(\.isOnGlassSheet, true)
                .environment(\.stopAnimatesIn, false)
                .id(contentKey)
        }
    }
}

struct ItineraryStopSheet: View {
    let place: Place
    @Binding var detent: PresentationDetent
    @Binding var compactHeight: CGFloat
    @State private var showTripSearch = false

    private var stop: SearchResult {
        SearchResult(
            type: .stop,
            tokens: [[]],
            name: place.name,
            id: place.parentId ?? place.stopId ?? "",
            lat: place.lat,
            lon: place.lon,
            level: Double(place.level),
            areas: [],
            score: 1.0
        )
    }

    private var details: [StopDepartureSheet.Detail] {
        var details: [StopDepartureSheet.Detail] = []
        if let arrival = place.arrival, let departure = place.departure, arrival != departure {
            details.append(.init(symbol: "arrow.down.circle.fill", text: String(localized: "Arrivée prévue : \(Self.timeFormatter.string(from: arrival))")))
            details.append(.init(symbol: "arrow.up.circle.fill", text: String(localized: "Départ à : \(Self.timeFormatter.string(from: departure))")))
        } else if let departure = place.departure {
            details.append(.init(symbol: "clock", text: String(localized: "Départ à : \(Self.timeFormatter.string(from: departure))")))
        } else if let arrival = place.arrival {
            details.append(.init(symbol: "clock", text: String(localized: "Arrivée prévue : \(Self.timeFormatter.string(from: arrival))")))
        }
        if let track = place.track {
            details.append(.init(symbol: "train.side.front.car", text: getTrackType(track)))
        }
        return details
    }

    var body: some View {
        NavigationStack {
            StopDepartureSheet(
                stop: stop,
                time: place.departure ?? place.arrival,
                details: details,
                onHeaderHeight: { height in
                    let compact = (height + Self.firstGroupHeight).rounded()
                    guard abs(compact - compactHeight) > 1 else { return }
                    let wasCompact = detent == .height(compactHeight)
                    compactHeight = compact
                    if wasCompact { detent = .height(compact) }
                },
                onGo: {
                    detent = .large
                    showTripSearch = true
                }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showTripSearch) {
                TripsSearchView(initialSearchResult: stop, initialTargetField: .to)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }

    static let firstGroupHeight: CGFloat = 330

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct TripDestination: Identifiable, Hashable {
    let id = UUID()
    let tripId: String
    var otherTripOptions: [TripOption] = []

    static func == (lhs: TripDestination, rhs: TripDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private struct OpenTripKey: EnvironmentKey {
    static let defaultValue: ((TripDestination) -> Void)? = nil
}

extension EnvironmentValues {
    var openTrip: ((TripDestination) -> Void)? {
        get { self[OpenTripKey.self] }
        set { self[OpenTripKey.self] = newValue }
    }
}
