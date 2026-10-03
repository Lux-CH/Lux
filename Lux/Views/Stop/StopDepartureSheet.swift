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
    var connections: [StopConnection]? = nil
    var showsDepartures = true
    var onHeaderHeight: (CGFloat) -> Void = { _ in }
    var onGo: (() -> Void)?

    private var shownDetails: [Detail] {
        guard let track else { return details }
        return [Detail(symbol: "signpost.right", text: getTrackType(track))] + details
    }

    @State private var loadedConnections: (stopId: String, lines: [StopConnection])?

    static let connectionRowHeight: CGFloat = 26

    private var shownConnections: [StopConnection] {
        if let connections { return connections }
        guard let loadedConnections, loadedConnections.stopId == stop.id else { return [] }
        return loadedConnections.lines
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
                    if !shownConnections.isEmpty {
                        ConnectionPillsRow(connections: shownConnections)
                            .transition(.opacity)
                    }
                    ForEach(shownDetails, id: \.self) { detail in
                        Label(detail.text, systemImage: detail.symbol)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let onGo {
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 14)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeaderHeight($0) }
            if showsDepartures {
                Divider()
                ExpandedStopView(stop: stop, fromStops: true, maxGroupsToShow: 50, time: time, track: track)
                    .contentMargins(.bottom, 30, for: .scrollContent)
                    .ignoresSafeArea(.container, edges: .bottom)
                    .environment(\.isOnGlassSheet, true)
                    .environment(\.stopAnimatesIn, false)
                    .id(contentKey)
            } else {
                Spacer(minLength: 0)
            }
        }
        .task(id: stop.id) {
            guard connections == nil, showsDepartures else { return }
            let stopId = stop.id
            let lines = await ConnectionService.shared.connections(for: stopId)
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) {
                loadedConnections = (stopId, lines)
            }
        }
    }
}

private struct ConnectionPillsRow: View {
    let connections: [StopConnection]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(connections, id: \.self) { connection in
                    LinePill(line: connection.line, mode: .bus, agency: connection.agency)
                }
            }
            .padding(.trailing, 30)
        }
        .frame(height: StopDepartureSheet.connectionRowHeight)
        .mask(
            HStack(spacing: 0) {
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 30)
            }
        )
    }
}

struct ItineraryStopSheet: View {
    let place: Place
    var connections: [StopConnection] = []
    var isEndpoint = false
    @Binding var detent: PresentationDetent
    @Binding var compactHeight: CGFloat
    let onGo: (SearchResult) -> Void

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

    static func details(for place: Place) -> [StopDepartureSheet.Detail] {
        var details: [StopDepartureSheet.Detail] = []
        if let arrival = place.arrival, let departure = place.departure, arrival != departure {
            details.append(.init(symbol: "arrow.down.circle.fill", text: String(localized: "Arrivée prévue : \(timeFormatter.string(from: arrival))")))
            details.append(.init(symbol: "arrow.up.circle.fill", text: String(localized: "Départ à : \(timeFormatter.string(from: departure))")))
        } else if let departure = place.departure {
            details.append(.init(symbol: "clock", text: String(localized: "Départ à : \(timeFormatter.string(from: departure))")))
        } else if let arrival = place.arrival {
            details.append(.init(symbol: "clock", text: String(localized: "Arrivée prévue : \(timeFormatter.string(from: arrival))")))
        }
        if let track = place.track {
            details.append(.init(symbol: "train.side.front.car", text: getTrackType(track)))
        }
        return details
    }

    static func estimatedCompactHeight(for place: Place, width: CGFloat, hasConnections: Bool, isEndpoint: Bool = false) -> CGFloat {
        let titleFont = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize, weight: .bold)
        let detailFont = UIFont.preferredFont(forTextStyle: .subheadline)
        let buttonFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let buttonWidth = (String(localized: "Y aller") as NSString).size(withAttributes: [.font: buttonFont]).width + 54
        let textWidth = max(80, isEndpoint ? width - 40 : width - 40 - 12 - buttonWidth)
        let titleHeight = min(
            (place.name as NSString).boundingRect(
                with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: [.font: titleFont],
                context: nil
            ).height,
            titleFont.lineHeight * 2
        )
        let detailCount = CGFloat(details(for: place).count)
        let connectionRow = hasConnections ? StopDepartureSheet.connectionRowHeight + 4 : 0
        let column = ceil(titleHeight) + connectionRow + detailCount * (ceil(detailFont.lineHeight) + 4)
        if isEndpoint {
            return (26 + 14 + column + endpointBottomInset).rounded()
        }
        let header = 26 + 14 + max(column, 38)
        return (header + firstGroupHeight).rounded()
    }

    var body: some View {
        NavigationStack {
            StopDepartureSheet(
                stop: stop,
                time: place.departure ?? place.arrival,
                details: Self.details(for: place),
                connections: connections,
                showsDepartures: !isEndpoint,
                onHeaderHeight: { height in
                    let compact = (height + (isEndpoint ? Self.endpointBottomInset : Self.firstGroupHeight)).rounded()
                    guard abs(compact - compactHeight) > 1 else { return }
                    let wasCompact = detent == .height(compactHeight)
                    compactHeight = compact
                    if wasCompact { detent = .height(compact) }
                },
                onGo: isEndpoint ? nil : {
                    onGo(stop)
                }
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    static let firstGroupHeight: CGFloat = 330
    static let endpointBottomInset: CGFloat = 24

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

final class TripOpener {
    var open: (TripDestination) -> Void = { _ in }

    func callAsFunction(_ trip: TripDestination) {
        open(trip)
    }
}

private struct OpenTripKey: EnvironmentKey {
    static let defaultValue: TripOpener? = nil
}

extension EnvironmentValues {
    var openTrip: TripOpener? {
        get { self[OpenTripKey.self] }
        set { self[OpenTripKey.self] = newValue }
    }
}
