//
//  OnboardJourneyTimeline.swift
//  Lux
//
//  Created by Constantin Clerc on 14.10.2026.
//

import SwiftUI
import LuxCom

struct OnboardJourneyTimeline: View {
    let session: OnboardSession
    @ObservedObject var itineraryViewModel: ItineraryViewModel
    var onOpenDisruptions: () -> Void = {}

    @ObservedObject private var settings = Settings.shared

    var body: some View {
        JourneyTimelineContent(
            model: JourneyModel(session: session, showsDelay: settings.showDelayInsteadOfDirectTime),
            onSelectStop: { itineraryViewModel.selectedStop = $0 },
            onOpenDisruptions: onOpenDisruptions
        )
        .equatable()
    }
}

private enum Margin: Equatable {
    case missed
    case tight
    case minutes(Int)

    init(_ seconds: TimeInterval) {
        if seconds < -30 {
            self = .missed
        } else if seconds < 120 {
            self = .tight
        } else {
            self = .minutes(Int(seconds / 60))
        }
    }
}

private enum Rail: Equatable {
    case line(Color)
    case walk
    case cycle
}

private struct StationModel: Equatable {
    var name: String
    var time: String
    var delay: String?
    var timeColor: Color
    var delayColor: Color
    var cancelled = false
    var track: String?
    var margin: Margin?
    var isDestination = false
    var place: Place?
}

private struct StopModel: Equatable {
    let name: String
    let time: String?
    let timeColor: Color
    let place: Place
}

private struct RideModel: Equatable {
    let legIndex: Int
    let line: String
    let mode: TransportationMode
    let agency: String?
    let title: String
    let detail: String
    let cancelled: Bool
    let disruption: String?
    let stops: [StopModel]
}

private struct WalkModel: Equatable {
    let detail: String
    let margin: Margin?
    var symbol = "figure.walk"
    var isCycling = false
}

private struct JourneyRow: Equatable, Identifiable {
    enum Kind: Equatable {
        case station(StationModel)
        case ride(RideModel)
        case walk(WalkModel)
    }

    let id: Int
    var kind: Kind
    var incoming: Rail?
    var outgoing: Rail?

    var isStation: Bool {
        if case .station = kind { return true }
        return false
    }

    var isDestination: Bool {
        if case .station(let station) = kind { return station.isDestination }
        return false
    }

    var dotColor: Color {
        for rail in [outgoing, incoming] {
            if case .line(let color) = rail { return color }
        }
        return .secondary
    }
}

private struct JourneyModel: Equatable {
    var transferCount = 0
    var rows: [JourneyRow] = []

    @MainActor
    init(session: OnboardSession, showsDelay: Bool) {
        let legs = session.legs
        let lastIndex = legs.count - 1
        guard lastIndex >= 0 else { return }

        let upcoming = legs.indices.filter { $0 > session.legIndex && legs[$0].isTransit && legs[$0].interlineWithPreviousLeg != true }.count
        transferCount = session.currentLeg?.isTransit == true ? upcoming : max(0, upcoming - 1)

        let lateArrival: Color? = {
            guard let last = legs.last(where: \.isTransit), last.realTime, last.arrivalDelayMinutes >= 2 else { return nil }
            return .orange
        }()

        func station(_ name: String, time: Date, place: Place?, leg: Leg?, track: String? = nil, isDestination: Bool = false) -> StationModel {
            let realTime = leg?.realTime ?? false
            let cancelled = leg?.cancelled ?? false
            let punctuality = place?.punctuality(realTime: realTime, cancelled: cancelled) ?? .scheduled
            let difference = place?.scheduledDifference() ?? 0
            var model = StationModel(
                name: name,
                time: formatTime(time),
                timeColor: punctuality.highlightColor ?? .primary,
                delayColor: punctuality.color,
                cancelled: cancelled,
                track: track,
                isDestination: isDestination,
                place: place?.stopId == nil ? nil : place
            )
            if isDestination, let lateArrival {
                model.timeColor = lateArrival
            } else if showsDelay, realTime, !cancelled, difference != 0,
                      let scheduled = place?.scheduledDeparture ?? place?.scheduledArrival {
                model.time = formatTime(scheduled)
                model.timeColor = .primary
                model.delay = "\(difference >= 0 ? "+" : "")\(difference)'"
            }
            return model
        }

        func trackLabel(_ place: Place) -> String? {
            guard let track = place.track ?? place.scheduledTrack, !track.isEmpty, track != "inconnu" else { return nil }
            return track
        }

        func margin(afterWalkAt index: Int) -> Margin? {
            let nextIndex = index + 1
            guard legs.indices.contains(nextIndex), legs[nextIndex].isTransit,
                  let previousIndex = (0..<index).last(where: { legs[$0].isTransit }),
                  previousIndex >= session.legIndex else { return nil }
            let walk = ((previousIndex + 1)..<nextIndex).reduce(0.0) { total, i in
                total + (legs[i].isTransit ? 0 : session.walkTime(ofLegAt: i))
            }
            let isLive = previousIndex == session.legIndex && session.phase == .riding
            let ready = (isLive ? session.currentLegArrival : legs[previousIndex].endTime).addingTimeInterval(walk)
            return Margin(legs[nextIndex].startTime.timeIntervalSince(ready))
        }

        var entries: [(kind: JourneyRow.Kind, rail: Rail?)] = []
        var pendingMargin: Margin?

        func addStation(_ next: StationModel) {
            if case .station(var last) = entries.last?.kind, last.name == next.name {
                last.time = next.time
                last.delay = next.delay
                last.timeColor = next.timeColor
                last.delayColor = next.delayColor
                last.cancelled = next.cancelled
                last.place = next.place ?? last.place
                last.track = next.track ?? last.track
                last.margin = pendingMargin ?? last.margin
                entries[entries.count - 1].kind = .station(last)
            } else {
                entries.append((.station(next), nil))
            }
        }

        if let current = session.currentLeg, current.isTransit {
            let isLast = session.legIndex == lastIndex
            addStation(station(
                session.placeName(current.to, isDestination: isLast),
                time: isLast ? session.arrivalDate : session.currentLegArrival,
                place: current.to,
                leg: current,
                isDestination: isLast
            ))
        }

        if session.legIndex + 1 <= lastIndex {
            for index in (session.legIndex + 1)...lastIndex {
                let leg = legs[index]
                if leg.isTransit {
                    if leg.interlineWithPreviousLeg != true || entries.isEmpty {
                        addStation(station(session.placeName(leg.from), time: leg.startTime, place: leg.from, leg: leg, track: trackLabel(leg.from)))
                    }
                    pendingMargin = nil
                    entries.append((.ride(Self.ride(leg, at: index, session: session)), .line(getOnboardLegColor(leg))))
                    let isLast = index == lastIndex
                    addStation(station(
                        session.placeName(leg.to, isDestination: isLast),
                        time: isLast ? session.arrivalDate : leg.endTime,
                        place: leg.to,
                        leg: leg,
                        track: trackLabel(leg.to),
                        isDestination: isLast
                    ))
                } else {
                    let sameStation = leg.from.name == leg.to.name && index < lastIndex
                    if !sameStation {
                        if entries.isEmpty {
                            addStation(station(session.placeName(leg.from), time: leg.startTime, place: leg.from, leg: nil))
                        }
                        if leg.mode.isCycling {
                            entries.append((.walk(WalkModel(detail: Self.rideDetail(leg), margin: margin(afterWalkAt: index), symbol: leg.bikeSymbol, isCycling: true)), .cycle))
                        } else {
                            entries.append((.walk(WalkModel(detail: Self.walkDetail(leg), margin: margin(afterWalkAt: index))), .walk))
                        }
                    } else {
                        pendingMargin = margin(afterWalkAt: index)
                    }
                    if index == lastIndex {
                        addStation(station(session.placeName(leg.to, isDestination: true), time: session.arrivalDate, place: leg.to, leg: nil, isDestination: true))
                    }
                }
            }
        }

        rows = entries.enumerated().map { offset, entry in
            JourneyRow(
                id: offset,
                kind: entry.kind,
                incoming: offset > 0 ? entries[offset - 1].rail : nil,
                outgoing: offset + 1 < entries.count ? entries[offset + 1].rail : nil
            )
        }
    }

    @MainActor
    private static func ride(_ leg: Leg, at index: Int, session: OnboardSession) -> RideModel {
        let stops = leg.intermediateStops ?? []
        let duration = durationText(leg.duration)
        let detail: String
        if stops.isEmpty {
            detail = duration
        } else {
            detail = "\(duration) · \(stops.count == 1 ? String(localized: "1 arrêt") : String(localized: "\(stops.count) arrêts"))"
        }
        let disruptions = session.legDisruptions.filter { $0.legIndex == index }
        let disruption: String? = disruptions.isEmpty ? nil
            : disruptions.count == 1 ? disruptions[0].disruption.shortTitle
            : String(localized: "\(disruptions.count) perturbations")
        return RideModel(
            legIndex: index,
            line: leg.routeShortName ?? "",
            mode: leg.mode,
            agency: leg.agencyId,
            title: leg.headsign ?? session.placeName(leg.to),
            detail: detail,
            cancelled: leg.cancelled,
            disruption: disruption,
            stops: stops.map { stop in
                StopModel(
                    name: stop.name,
                    time: (stop.arrival ?? stop.departure ?? stop.scheduledArrival ?? stop.scheduledDeparture).map(formatTime),
                    timeColor: stop.punctuality(realTime: leg.realTime, cancelled: leg.cancelled).highlightColor ?? .secondary,
                    place: stop
                )
            }
        )
    }

    private static func walkDetail(_ leg: Leg) -> String {
        let minutes = String(localized: "\(max(1, leg.duration / 60)) min à pied")
        guard let distance = leg.distance, distance >= 20 else { return minutes }
        return "\(minutes) · \(formatDistance(distance))"
    }

    private static func rideDetail(_ leg: Leg) -> String {
        let minutes = String(localized: "\(max(1, leg.duration / 60)) min à vélo")
        let network = leg.rental?.systemName.map { " · \($0)" } ?? ""
        guard let distance = leg.distance, distance >= 20 else { return minutes + network }
        return "\(minutes) · \(formatDistance(distance))\(network)"
    }

    private static func durationText(_ seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        return minutes >= 60 ? "\(minutes / 60) h \(String(format: "%02d", minutes % 60))" : "\(minutes) min"
    }
}

private struct JourneyTimelineContent: View, Equatable {
    let model: JourneyModel
    let onSelectStop: (Place) -> Void
    let onOpenDisruptions: () -> Void

    @State private var expandedLegs: Set<Int> = []

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Suite du trajet")
                    .font(.headline)
                Spacer()
                if model.transferCount > 0 {
                    Text(model.transferCount == 1 ? String(localized: "1 correspondance") : String(localized: "\(model.transferCount) correspondances"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.rows) { row in
                    switch row.kind {
                    case .station(let station):
                        stationRow(station, id: row.id, color: row.dotColor)
                    case .ride(let ride):
                        rideRows(ride, color: row.outgoing.flatMap { if case .line(let color) = $0 { return color } else { return nil } } ?? row.dotColor)
                    case .walk(let walk):
                        walkRow(walk)
                    }
                }
            }
            .backgroundPreferenceValue(StationDotKey.self) { anchors in
                GeometryReader { proxy in
                    let pieces = railPieces(anchors: anchors, proxy: proxy)
                    Canvas { context, _ in
                        for piece in pieces {
                            draw(piece, in: &context)
                        }
                    }
                }
            }
        }
    }

    private func stationRow(_ station: StationModel, id: Int, color: Color) -> some View {
        Button {
            guard let place = station.place else { return }
            HapticFeedback.selectionChanged()
            onSelectStop(place)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(station.name)
                    .font(.subheadline.weight(station.isDestination ? .bold : .semibold))
                    .lineLimit(1)
                if let track = station.track {
                    TrackBadge(track: track)
                }
                if let margin = station.margin, margin == .tight || margin == .missed {
                    MarginBadge(margin: margin)
                        .fixedSize()
                }
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    if let delay = station.delay {
                        Text(delay)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(station.delayColor)
                    }
                    Text(station.time)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .strikethrough(station.cancelled, color: .red)
                        .foregroundStyle(station.timeColor)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .railed(.station(id: id, color: color, isDestination: station.isDestination))
    }

    @ViewBuilder
    private func rideRows(_ ride: RideModel, color: Color) -> some View {
        let isExpanded = expandedLegs.contains(ride.legIndex)

        Button {
            guard !ride.stops.isEmpty else { return }
            HapticFeedback.selectionChanged()
            withAnimation(.snappy(duration: 0.3)) {
                if isExpanded { expandedLegs.remove(ride.legIndex) } else { expandedLegs.insert(ride.legIndex) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    LinePill(line: ride.line, mode: ride.mode, agency: ride.agency, width: 38, height: 22, fontSize: 12, usesOriginalColors: true)
                    Text(ride.title)
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if !ride.stops.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                HStack(spacing: 6) {
                    Text(ride.detail)
                        .foregroundStyle(.secondary)
                    if ride.cancelled {
                        Text("Course supprimée")
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .railed(.none)

        if let disruption = ride.disruption {
            Button(action: onOpenDisruptions) {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(disruption)
                        .lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .railed(.none)
        }

        if isExpanded {
            VStack(spacing: 0) {
                ForEach(Array(ride.stops.enumerated()), id: \.offset) { _, stop in
                    stopRow(stop)
                }
            }
            .padding(.bottom, 4)
            .transition(.opacity)
        }
    }

    private func stopRow(_ stop: StopModel) -> some View {
        Button {
            onSelectStop(stop.place)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(stop.name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let time = stop.time {
                    Text(time)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(stop.timeColor)
                }
            }
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .railed(.stop)
    }

    private func walkRow(_ walk: WalkModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: walk.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(walk.isCycling ? Color.bikeLeg : Color.secondary)
            Text(walk.detail)
            Spacer(minLength: 8)
            if let margin = walk.margin {
                MarginBadge(margin: margin)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 9)
        .railed(.none)
    }

    private struct RailPiece {
        let rail: Rail
        let from: CGPoint
        let to: CGPoint
        let endsAtDestination: Bool
    }

    private func railPieces(anchors: [Int: Anchor<CGPoint>], proxy: GeometryProxy) -> [RailPiece] {
        let stations = model.rows.filter(\.isStation)
        return zip(stations, stations.dropFirst()).compactMap { from, to in
            guard let rail = from.outgoing, let start = anchors[from.id], let end = anchors[to.id] else { return nil }
            return RailPiece(rail: rail, from: proxy[start], to: proxy[end], endsAtDestination: to.isDestination)
        }
    }

    private func draw(_ piece: RailPiece, in context: inout GraphicsContext) {
        switch piece.rail {
        case .line(let color):
            let rect = CGRect(x: piece.from.x - 2.5, y: piece.from.y, width: 5, height: max(0, piece.to.y - piece.from.y))
            context.fill(Path(rect), with: .color(color))
        case .walk, .cycle:
            let start = piece.from.y + 12
            let end = piece.to.y - (piece.endsAtDestination ? 8 : 6) - 6
            guard end > start else { return }
            let count = max(2, Int(((end - start) / 7).rounded()) + 1)
            let step = (end - start) / CGFloat(count - 1)
            var path = Path()
            for index in 0..<count {
                let y = start + step * CGFloat(index)
                path.addEllipse(in: CGRect(x: piece.from.x - 1.75, y: y - 1.75, width: 3.5, height: 3.5))
            }
            context.fill(path, with: .color(piece.rail == .cycle ? Color.bikeLeg : .secondary.opacity(0.6)))
        }
    }
}

private struct MarginBadge: View {
    let margin: Margin

    var body: some View {
        switch margin {
        case .missed:
            Label("Compromis", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .labelStyle(TightLabelStyle())
        case .tight:
            Label("Serré", systemImage: "hare.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .labelStyle(TightLabelStyle())
        case .minutes(let minutes):
            Text(String(localized: "\(minutes) min de marge"))
        }
    }
}

private struct StationDotKey: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGPoint>] = [:]

    static func reduce(value: inout [Int: Anchor<CGPoint>], nextValue: () -> [Int: Anchor<CGPoint>]) {
        value.merge(nextValue()) { $1 }
    }
}

private enum RailMarker {
    case station(id: Int, color: Color, isDestination: Bool)
    case stop
    case none
}

private let railWidth: CGFloat = 20
private let railGap: CGFloat = 14
private let stationDotOffset: CGFloat = 17
private let stopDotOffset: CGFloat = 14.5

private extension View {
    func railed(_ marker: RailMarker) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, railWidth + railGap)
            .background(alignment: .topLeading) {
                RailMarkerView(marker: marker)
                    .frame(width: railWidth)
            }
    }
}

private struct RailMarkerView: View {
    let marker: RailMarker

    var body: some View {
        switch marker {
        case .station(let id, let color, let isDestination):
            let size: CGFloat = isDestination ? 16 : 12
            Group {
                if isDestination {
                    Circle()
                        .fill(Color.primary)
                        .overlay(Circle().fill(Color(.systemBackground)).frame(width: 6, height: 6))
                } else {
                    Circle()
                        .fill(Color(.systemBackground))
                        .overlay(Circle().stroke(color, lineWidth: 3))
                }
            }
            .frame(width: size, height: size)
            .anchorPreference(key: StationDotKey.self, value: .center) { [id: $0] }
            .offset(y: stationDotOffset - size / 2)
        case .stop:
            Circle()
                .fill(Color(.systemBackground).opacity(0.9))
                .frame(width: 5, height: 5)
                .offset(y: stopDotOffset - 2.5)
        case .none:
            Color.clear
                .frame(width: 0, height: 0)
        }
    }
}

private struct TrackBadge: View {
    let track: String

    var body: some View {
        Text(track)
            .font(.system(size: 8))
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary.opacity(0.8))
            .lineLimit(1)
            .padding(.horizontal, track.count > 1 ? 2 : 0)
            .frame(minWidth: 11, minHeight: 11)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.secondary.opacity(0.8), lineWidth: 0.5)
            )
            .fixedSize()
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}
