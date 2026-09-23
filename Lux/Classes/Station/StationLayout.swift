//
//  StationLayout.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import CoreLocation
import MapKit
import LuxCom

/// In-station layout served by the relay (`sub_sta`): SBB platform edges per public
/// track number, sector letters and platforms, joined with MOTIS's per-track stops.
struct StationLayout: Decodable, Sendable, Equatable {
    let uic: Int
    let name: String?
    let lat: Double
    let lon: Double
    let levels: [Double]
    let tracks: [Track]
    let platforms: [Platform]?
    let rails: [Rail]?
    let empty: Bool

    /// OSM rail around the station; `track` when it runs along a platform edge.
    struct Rail: Decodable, Sendable, Equatable {
        let track: String?
        let siding: Bool?
        let line: [[Double]]

        var coordinates: [CLLocationCoordinate2D] {
            line.compactMap { point in
                point.count >= 2 ? CLLocationCoordinate2D(latitude: point[0], longitude: point[1]) : nil
            }
        }
    }

    struct Track: Decodable, Sendable, Equatable {
        let track: String
        let edges: [[[Double]]]
        let stopIds: [String]
        let sectors: [Sector]
        let platform: Platform?
        let lat: Double
        let lon: Double

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }

        var edgeCoordinates: [[CLLocationCoordinate2D]] {
            edges.map { edge in
                edge.compactMap { point in
                    point.count >= 2 ? CLLocationCoordinate2D(latitude: point[0], longitude: point[1]) : nil
                }
            }
        }
    }

    struct Sector: Decodable, Sendable, Equatable {
        let s: String
        let lat: Double
        let lon: Double

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    }

    struct Platform: Decodable, Sendable, Equatable {
        let name: String?
        let type: String?
        let length: Double?
        /// Surface outline; only on `StationLayout.platforms`, not on a track's platform info.
        let tracks: [String]?
        let ring: [[Double]]?

        var ringCoordinates: [CLLocationCoordinate2D] {
            (ring ?? []).compactMap { point in
                point.count >= 2 ? CLLocationCoordinate2D(latitude: point[0], longitude: point[1]) : nil
            }
        }
    }

    func track(named name: String?, stopId: String?) -> Track? {
        if let name = name.map(StationLayout.normalizedTrack), !name.isEmpty,
           let match = tracks.first(where: { $0.track == name }) {
            return match
        }
        guard let stopId else { return nil }
        return tracks.first { $0.stopIds.contains(stopId) }
    }

    /// Mirrors the relay: "010" and "10" are the same public track.
    static func normalizedTrack(_ track: String) -> String {
        let trimmed = track.trimmingCharacters(in: .whitespaces)
        let stripped = trimmed.drop { $0 == "0" }
        return stripped.isEmpty ? trimmed : String(stripped)
    }

    /// Any MOTIS id (ch_ch:1:sloid:1008, ch_Parentch:1:sloid:1008, ch_ch:1:sloid:1008:4:7) -> 8501008
    static func uic(fromStopId stopId: String?) -> Int? {
        guard let stopId, let range = stopId.range(of: "sloid:") else { return nil }
        let digits = stopId[range.upperBound...].prefix { $0.isNumber }
        guard (1...6).contains(digits.count), let number = Int(digits) else { return nil }
        return 8_500_000 + number
    }
}

@MainActor
final class StationLayoutStore {
    static let shared = StationLayoutStore()

    private var layouts: [Int: StationLayout] = [:]
    private var missing: [Int: Date] = [:]
    private var inflight: [Int: Task<StationLayout?, Never>] = [:]

    private init() {}

    func cached(uic: Int) -> StationLayout? {
        layouts[uic]
    }

    func layout(for stopId: String) async -> StationLayout? {
        guard let uic = StationLayout.uic(fromStopId: stopId) else { return nil }
        if let layout = layouts[uic] { return layout }
        if let at = missing[uic], Date().timeIntervalSince(at) < 600 { return nil }
        if let task = inflight[uic] { return await task.value }

        let task = Task<StationLayout?, Never> {
            await Self.fetch(stationId: "\(uic)")
        }
        inflight[uic] = task
        let layout = await task.value
        inflight[uic] = nil
        if let layout, !layout.empty {
            layouts[uic] = layout
            return layout
        }
        missing[uic] = Date()
        return nil
    }

    /// Layouts of the stations where the itinerary boards or leaves a train.
    func layouts(for legs: [Leg]) async -> [Int: StationLayout] {
        guard !OfflineRouter.shared.isOfflineActive else { return [:] }
        var stopIds: [Int: String] = [:]
        for leg in legs where leg.mode.isMainlineRail {
            for place in [leg.from, leg.to] {
                if let stopId = place.stopId, let uic = StationLayout.uic(fromStopId: stopId) {
                    stopIds[uic] = stopId
                }
            }
        }
        var result: [Int: StationLayout] = [:]
        await withTaskGroup(of: StationLayout?.self) { group in
            for stopId in stopIds.values {
                group.addTask { await self.layout(for: stopId) }
            }
            for await layout in group {
                if let layout { result[layout.uic] = layout }
            }
        }
        return result
    }

    private static func fetch(stationId: String) async -> StationLayout? {
        let stream = await RelayClient.shared.station(stationId: stationId)
        return await withTaskGroup(of: StationLayout??.self) { group in
            group.addTask {
                for await layout in stream { return .some(layout) }
                return .some(nil)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }
}

/// What both itinerary maps draw for a station: rails, platforms and their edges, signs.
/// The itinerary's tracks get a tinted platform, a darker rail in the line's colour (the
/// route runs on it) and a callout; platform edges and outlines stay neutral.
struct StationOverlayContent {
    struct Line: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
    }

    /// A track sign; `color` is set on the itinerary's own tracks.
    struct Label: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let text: String
        let color: Color?
        let accessibilityText: String
    }

    struct Area: Identifiable {
        let id: String
        let coordinates: [CLLocationCoordinate2D]
        let color: Color?
    }

    var areas: [Area] = []
    /// Rail outlines (band + sleepers, `RailShape`), sized on the ground like the map itself.
    var rails: [Area] = []
    var lines: [Line] = []
    var labels: [Label] = []

    var isEmpty: Bool { areas.isEmpty && rails.isEmpty && lines.isEmpty && labels.isEmpty }

    init() {}

    init(legs: [Leg], layouts: [Int: StationLayout]) {
        guard !layouts.isEmpty else { return }

        // departure track wins over arrival track when a train leaves where another arrives
        var highlights: [Int: [String: Color]] = [:]
        // where the itinerary's stop pins sit, so track signs keep clear of them
        var pins: [Int: [CLLocationCoordinate2D]] = [:]
        for leg in legs.reversed() where leg.mode.isMainlineRail {
            let color = getLegColor(leg)
            for place in [leg.to, leg.from] {
                guard let uic = StationLayout.uic(fromStopId: place.stopId), let layout = layouts[uic] else { continue }
                pins[uic, default: []].append(CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon))
                guard let track = layout.track(named: place.track ?? place.scheduledTrack, stopId: place.stopId) else { continue }
                highlights[uic, default: [:]][track.track] = color
            }
        }

        for (uic, layout) in layouts.sorted(by: { $0.key < $1.key }) {
            let highlighted = highlights[uic] ?? [:]
            let stationPins = pins[uic] ?? []
            for (index, rail) in (layout.rails ?? []).enumerated() {
                let coordinates = rail.coordinates
                guard coordinates.count >= 2 else { continue }
                let color = rail.track.flatMap { highlighted[$0] }
                let outline = RailShape.outline(of: coordinates, style: color == nil ? StationStyle.rail : StationStyle.ourRail)
                guard outline.count >= 3 else { continue }
                rails.append(Area(id: "\(uic)-r-\(index)", coordinates: outline, color: color))
            }
            for platform in layout.platforms ?? [] {
                let ring = platform.ringCoordinates
                guard ring.count >= 3 else { continue }
                let color = (platform.tracks ?? []).lazy.compactMap { highlighted[$0] }.first
                areas.append(Area(id: "\(uic)-p-\(platform.name ?? "\(areas.count)")", coordinates: ring, color: color))
            }
            for (trackIndex, track) in layout.tracks.enumerated() {
                let color = highlighted[track.track]
                let edges = track.edgeCoordinates.filter { $0.count >= 2 }
                for (index, edge) in edges.enumerated() {
                    lines.append(Line(id: "\(uic)-\(track.track)-\(index)", coordinates: edge))
                }
                labels.append(Label(
                    id: "\(uic)-\(track.track)",
                    coordinate: Self.signCoordinate(
                        for: track,
                        edges: edges,
                        staggered: trackIndex.isMultiple(of: 2),
                        avoiding: stationPins
                    ),
                    text: track.track,
                    color: color,
                    accessibilityText: getTrackType(track.track)
                ))
            }
        }
        // the itinerary's signs last, so they always sit on top of their neighbours
        labels.sort { ($0.color == nil ? 0 : 1) < ($1.color == nil ? 0 : 1) }
        // highlighted tracks draw last so they sit on top of their neighbours
        rails.sort { ($0.color == nil ? 0 : 1) < ($1.color == nil ? 0 : 1) }
    }

    /// Like SBB's plans: signs sit on the track, alternating between the two halves of
    /// the platform so neighbours don't line up, and never on top of a stop pin.
    private static func signCoordinate(
        for track: StationLayout.Track,
        edges: [[CLLocationCoordinate2D]],
        staggered: Bool,
        avoiding pins: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D {
        guard let edge = edges.max(by: { length(of: $0) < length(of: $1) }) else { return track.coordinate }
        let preferred = staggered ? 0.3 : 0.7
        let candidates = stride(from: 0.1, through: 0.9, by: 0.025)
            .sorted { abs($0 - preferred) < abs($1 - preferred) }
            .map { point(on: edge, at: $0) }
        func clearance(_ coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
            pins.map { coordinate.distance(to: $0) }.min() ?? .infinity
        }
        return candidates.first { clearance($0) >= 45 } ?? candidates.max { clearance($0) < clearance($1) } ?? track.coordinate
    }

    private static func length(of line: [CLLocationCoordinate2D]) -> CLLocationDistance {
        zip(line, line.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }

    private static func point(on line: [CLLocationCoordinate2D], at fraction: Double) -> CLLocationCoordinate2D {
        var remaining = length(of: line) * fraction
        for (a, b) in zip(line, line.dropFirst()) {
            let segment = a.distance(to: b)
            if segment >= remaining, segment > 0 {
                let t = remaining / segment
                return CLLocationCoordinate2D(
                    latitude: a.latitude + (b.latitude - a.latitude) * t,
                    longitude: a.longitude + (b.longitude - a.longitude) * t
                )
            }
            remaining -= segment
        }
        return line.last ?? line[0]
    }
}

/// How much of a station to draw for a given camera distance.
enum StationDetail: Int, Comparable {
    case hidden, tracks, labels, allLabels

    init(cameraDistance distance: CLLocationDistance) {
        switch distance {
        case ..<1400: self = .allLabels
        case ..<2800: self = .labels
        case ..<6000: self = .tracks
        default: self = .hidden
        }
    }

    static func < (lhs: StationDetail, rhs: StationDetail) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension StationOverlayContent {
    /// Labels worth showing at a zoom level: from afar only the itinerary's own
    /// tracks (a whole station's signs would pile up), every sign up close.
    func visibleLabels(at detail: StationDetail) -> [Label] {
        switch detail {
        case .hidden, .tracks: return []
        case .labels: return labels.filter { $0.color != nil }
        case .allLabels: return labels
        }
    }
}

/// Shared look of the station layer (SBB signage), for SwiftUI and MapKit renderers.
enum StationStyle {
    static let signBlue = Color(red: 0.176, green: 0.196, blue: 0.490) // SBB #2D327D

    /// Platform edges the itinerary doesn't use: readable on both map themes.
    static let idleEdge = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.45)
            : UIColor.black.withAlphaComponent(0.35)
    }
    static let idleEdgeWidth: CGFloat = 2.5

    /// Platform surfaces (SBB's "quais"): a pale fill on both map themes.
    static let platformFill = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.13)
            : UIColor(red: 0.96, green: 0.92, blue: 0.91, alpha: 0.95)
    }
    static let platformStroke = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.25)
            : UIColor(red: 0.78, green: 0.62, blue: 0.62, alpha: 0.8)
    }
    static let highlightedPlatformOpacity: CGFloat = 0.25

    /// Rails (OSM), drawn like Apple Maps: a thin band crossed by sleepers. All sizes
    /// are metres on the ground, so rails zoom with the map like any other feature.
    struct Rail {
        let band: Double
        let tieLength: Double
        let tieThickness: Double
        let tieSpacing: Double
    }

    static let idleRail = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.55)
            : UIColor(white: 0.45, alpha: 0.8)
    }
    static let rail = Rail(band: 0.45, tieLength: 2.2, tieThickness: 0.3, tieSpacing: 3.2)
    static let ourRail = Rail(band: 0.7, tieLength: 2.4, tieThickness: 0.35, tieSpacing: 3.2)
    /// The itinerary's rail: a darker shade of the line's colour, so its sleepers stay
    /// visible on both sides of the (brighter) route drawn on top of it.
    static func ourRailColor(for lineColor: Color) -> UIColor {
        var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        guard UIColor(lineColor).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return UIColor(lineColor)
        }
        return UIColor(hue: hue, saturation: min(1, saturation * 1.1), brightness: brightness * 0.55, alpha: 1)
    }
}

/// SBB-style track sign (dark blue, white number, "Voie"/"Quai" caption); the
/// itinerary's tracks get a callout ringed in the line's colour.
struct StationLabelView: View {
    let label: StationOverlayContent.Label

    private var isHighlighted: Bool { label.color != nil }

    private var caption: String {
        Int(label.text) != nil ? String(localized: "Voie") : String(localized: "Quai")
    }

    var body: some View {
        Group {
            if isHighlighted {
                callout
            } else {
                VStack(spacing: -1) {
                    Text(caption)
                        .font(.system(size: 5, weight: .semibold))
                        .textCase(.uppercase)
                    Text(label.text)
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .frame(minWidth: 20)
                .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(StationStyle.signBlue))
                .padding(1)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(.white))
                .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
            }
        }
        .fixedSize()
        .environment(\.colorScheme, .light)
        .accessibilityElement()
        .accessibilityLabel(Text(label.accessibilityText))
    }

    /// The itinerary's track: one horizontal "VOIE 3" sign pointing down at its rail
    /// (anchored at the tip, see `anchorsAtBottom`).
    private var callout: some View {
        VStack(spacing: -1) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(caption)
                    .font(.system(size: 8, weight: .semibold))
                    .textCase(.uppercase)
                Text(label.text)
                    .font(.system(size: 15, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(StationStyle.signBlue))
            .padding(2)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(label.color ?? .white))
            CalloutPointer()
                .fill(label.color ?? .white)
                .frame(width: 10, height: Self.pointerHeight)
        }
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }

    static let pointerHeight: CGFloat = 6

    /// Whether the view's anchor is its bottom tip rather than its centre.
    static func anchorsAtBottom(_ label: StationOverlayContent.Label) -> Bool {
        label.color != nil
    }
}

private struct CalloutPointer: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Station layer for SwiftUI `Map`s; the MKMapView-based maps draw the same content as overlays.
struct StationMapContent: MapContent {
    let content: StationOverlayContent
    let detail: StationDetail

    var body: some MapContent {
        if detail >= .tracks {
            ForEach(content.rails.filter { $0.color == nil }) { rail in
                MapPolygon(coordinates: rail.coordinates)
                    .foregroundStyle(Color(StationStyle.idleRail))
            }
            ForEach(content.areas) { area in
                MapPolygon(coordinates: area.coordinates)
                    .foregroundStyle(area.color.map { $0.opacity(StationStyle.highlightedPlatformOpacity) } ?? Color(StationStyle.platformFill))
                    .stroke(Color(StationStyle.platformStroke), lineWidth: 1)
            }
            ForEach(content.rails.filter { $0.color != nil }) { rail in
                MapPolygon(coordinates: rail.coordinates)
                    .foregroundStyle(Color(StationStyle.ourRailColor(for: rail.color ?? .red)))
            }
            ForEach(content.lines) { line in
                MapPolyline(coordinates: line.coordinates)
                    .stroke(Color(StationStyle.idleEdge), style: StrokeStyle(lineWidth: StationStyle.idleEdgeWidth, lineCap: .round))
            }
        }
        if detail >= .labels {
            ForEach(content.visibleLabels(at: detail)) { label in
                Annotation("", coordinate: label.coordinate, anchor: StationLabelView.anchorsAtBottom(label) ? .bottom : .center) {
                    StationLabelView(label: label)
                }
                .annotationTitles(.hidden)
            }
        }
    }
}

/// A rail and its sleepers as one polygon (sleepers cross the band, so the union is a
/// single "ladder" outline): up the left side with a tooth per sleeper, back down the
/// right side. Built in local metres around the rail's first point.
enum RailShape {
    static func outline(of line: [CLLocationCoordinate2D], style: StationStyle.Rail) -> [CLLocationCoordinate2D] {
        guard let origin = line.first, line.count >= 2 else { return [] }
        let metresPerLat = 111_132.0
        let metresPerLon = 111_320.0 * cos(origin.latitude * .pi / 180)
        let xy = line.map { ((($0.longitude - origin.longitude) * metresPerLon), (($0.latitude - origin.latitude) * metresPerLat)) }

        var along: [Double] = [0]
        for i in 1..<xy.count {
            along.append(along[i - 1] + hypot(xy[i].0 - xy[i - 1].0, xy[i].1 - xy[i - 1].1))
        }
        guard let total = along.last, total > 0.5 else { return [] }

        // position and unit normal (left of travel) at a distance along the rail
        func frame(at s: Double) -> (x: Double, y: Double, nx: Double, ny: Double) {
            var i = 1
            while i < along.count - 1, along[i] < s { i += 1 }
            let (a, b) = (xy[i - 1], xy[i])
            let length = max(along[i] - along[i - 1], 1e-6)
            let t = min(1, max(0, (s - along[i - 1]) / length))
            let (dx, dy) = ((b.0 - a.0) / length, (b.1 - a.1) / length)
            return (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, -dy, dx)
        }

        // (distance along, half-width) stations for one side: vertices sit on the band,
        // each sleeper steps out to its half-length and back
        var stations: [(Double, Double)] = along.map { ($0, style.band / 2) }
        var tie = style.tieSpacing / 2
        while tie + style.tieThickness / 2 < total {
            let (start, end) = (tie - style.tieThickness / 2, tie + style.tieThickness / 2)
            stations += [(start, style.band / 2), (start, style.tieLength / 2), (end, style.tieLength / 2), (end, style.band / 2)]
            tie += style.tieSpacing
        }
        // stable order keeps each sleeper's four corners in sequence
        stations = stations.enumerated()
            .sorted { $0.element.0 == $1.element.0 ? $0.offset < $1.offset : $0.element.0 < $1.element.0 }
            .map(\.element)

        func point(_ station: (Double, Double), side: Double) -> CLLocationCoordinate2D {
            let f = frame(at: station.0)
            let x = f.x + f.nx * station.1 * side
            let y = f.y + f.ny * station.1 * side
            return CLLocationCoordinate2D(latitude: origin.latitude + y / metresPerLat, longitude: origin.longitude + x / metresPerLon)
        }
        return stations.map { point($0, side: 1) } + stations.reversed().map { point($0, side: -1) }
    }
}
