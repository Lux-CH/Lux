//
//  OnboardModels.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import Foundation
import MapKit
import SwiftUI
import LuxCom

enum OnboardPhase: Equatable {
    case walking
    case waiting
    case riding
    case arrived
}

struct WalkManeuver: Equatable {
    let symbolName: String
    let instruction: String
    let shortInstruction: String
    let along: CLLocationDistance
    /// Stairs / lift / ramp inside a station, marked on the onboard map.
    var isLevelChange = false
}

struct OnboardAlert: Identifiable, Equatable {
    enum Severity {
        case info, success, warning, critical

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }

    let id = UUID()
    let severity: Severity
    let symbolName: String
    let title: String
    let message: String?

    static func == (lhs: OnboardAlert, rhs: OnboardAlert) -> Bool { lhs.id == rhs.id }
}

struct CrowdStatus: Equatable {
    enum State: Equatable {
        case learning
        case contributing(riders: Int, delaySeconds: Int)
        case unverified
    }

    let state: State
}

enum ConnectionRisk: Equatable {
    case comfortable
    case tight
    case missed
}

enum WalkManeuverBuilder {
    static func maneuvers(
        for steps: [StepInstruction],
        on path: RoutePath,
        station: StationWalk? = nil,
        access: [StationLayout.Access] = []
    ) -> [WalkManeuver] {
        guard !path.isEmpty else { return [] }
        if let station {
            return stationManeuvers(for: steps, on: path, walk: station, access: access)
        }

        var named: [(along: CLLocationDistance, street: String)] = []
        var explicit: [WalkManeuver] = []
        let starts = steps.map { step -> CLLocationCoordinate2D? in
            let precision = pow(10, Double(step.polyline.precision > 0 ? step.polyline.precision : 7))
            return RoutePath(encoded: step.polyline.points, precision: precision).coordinates.first
        }
        let located = zip(steps, starts).compactMap { step, start in start.map { (step, $0) } }
        let positions = path.projectSequence(located.map(\.1))
        for ((step, _), along) in zip(located, positions) {
            let street = step.streetName.trimmingCharacters(in: .whitespaces)
            if !street.isEmpty { named.append((along, street)) }
            let changesLevel = step.fromLevel != step.toLevel
            let isInformative = ![.continueStraight, .depart].contains(step.relativeDirection) || changesLevel
            guard isInformative, along > 3 else { continue }
            let direction: Direction = changesLevel && step.relativeDirection == .continueStraight ? .stairs : step.relativeDirection
            explicit.append(WalkManeuver(
                symbolName: symbol(for: direction),
                instruction: instruction(for: direction, street: street, exit: step.exit),
                shortInstruction: instruction(for: direction, street: "", exit: step.exit),
                along: along
            ))
        }

        let turns = geometricTurns(on: path).compactMap { turn -> WalkManeuver? in
            guard !explicit.contains(where: { abs($0.along - turn.along) < 15 }) else { return nil }
            let street = named.first { $0.along >= turn.along - 8 && $0.along <= turn.along + 40 }?.street ?? ""
            return WalkManeuver(
                symbolName: symbol(for: turn.direction),
                instruction: instruction(for: turn.direction, street: street, exit: ""),
                shortInstruction: instruction(for: turn.direction, street: "", exit: ""),
                along: turn.along
            )
        }
        return (explicit + turns).sorted { $0.along < $1.along }
    }

    /// Inside a station, what matters is going up or down and where to: stairs, lifts
    /// and ramps, the last one naming the track (or the exit). MOTIS reports some level
    /// changes only as a jump between two steps, and indoor corridors have no names, so
    /// levels are compared across steps. On transfers, corridor bends aren't announced.
    private static func stationManeuvers(
        for steps: [StepInstruction],
        on path: RoutePath,
        walk: StationWalk,
        access: [StationLayout.Access]
    ) -> [WalkManeuver] {
        let starts = steps.map { step -> CLLocationCoordinate2D? in
            let precision = pow(10, Double(step.polyline.precision > 0 ? step.polyline.precision : 7))
            return RoutePath(encoded: step.polyline.points, precision: precision).coordinates.first
        }
        let located = zip(steps, starts).compactMap { step, start in start.map { (step, $0) } }
        let positions = path.projectSequence(located.map(\.1))

        struct LevelChange {
            let along: CLLocationDistance
            let up: Bool
            let direction: Direction
        }
        // A stairs / ramp step carries its way's level *range* (low to high, whatever the
        // walking direction), so direction comes from the flat levels before and after it.
        var changes: [LevelChange] = []
        var turns: [WalkManeuver] = []
        var level: Double?
        var transition: (along: CLLocationDistance, direction: Direction, range: (Double, Double))?
        // the far end of a stairway's range from a known level (walks that start or end on stairs)
        func otherEnd(of range: (Double, Double), from known: Double) -> Double {
            abs(range.0 - known) > abs(range.1 - known) ? range.0 : range.1
        }
        for ((step, _), along) in zip(located, positions) {
            guard step.fromLevel == step.toLevel else {
                if transition == nil { transition = (along, step.relativeDirection, (step.fromLevel, step.toLevel)) }
                continue
            }
            let previous = level ?? transition.map { otherEnd(of: $0.range, from: step.toLevel) }
            if let previous, step.toLevel != previous {
                let via = transition.map { ($0.along, $0.direction) } ?? (along, step.relativeDirection)
                changes.append(LevelChange(along: max(via.0, 1), up: step.toLevel > previous, direction: via.1))
            }
            level = step.toLevel
            transition = nil
            if walk.kind != .transfer, ![.continueStraight, .depart, .stairs, .elevator].contains(step.relativeDirection), along > 3 {
                let street = step.streetName.trimmingCharacters(in: .whitespaces)
                turns.append(WalkManeuver(
                    symbolName: symbol(for: step.relativeDirection),
                    instruction: instruction(for: step.relativeDirection, street: street, exit: step.exit),
                    shortInstruction: instruction(for: step.relativeDirection, street: "", exit: step.exit),
                    along: along
                ))
            }
        }

        if let transition, let level {
            let end = otherEnd(of: transition.range, from: level)
            if end != level {
                changes.append(LevelChange(along: max(transition.along, 1), up: end > level, direction: transition.direction))
            }
        }

        let levelManeuvers = changes.enumerated().map { index, change -> WalkManeuver in
            let isLast = index == changes.count - 1
            let target: String? = switch walk.kind {
            case .leaving: isLast ? String(localized: "la sortie") : nil
            case .transfer, .entering: isLast ? walk.toTrack.map(StationWalk.trackPhrase) : nil
            }
            let means = LevelMeans(direction: change.direction, at: path.coordinate(at: change.along), access: access)
            let text = levelInstruction(means: means, up: change.up, target: target)
            return WalkManeuver(
                symbolName: levelSymbol(means: means, up: change.up),
                instruction: text,
                shortInstruction: text,
                along: change.along,
                isLevelChange: true
            )
        }

        var result = levelManeuvers + turns.filter { turn in !levelManeuvers.contains { abs($0.along - turn.along) < 15 } }
        if walk.kind != .transfer {
            result += geometricTurns(on: path).compactMap { turn -> WalkManeuver? in
                guard !result.contains(where: { abs($0.along - turn.along) < 15 }) else { return nil }
                return WalkManeuver(
                    symbolName: symbol(for: turn.direction),
                    instruction: instruction(for: turn.direction, street: "", exit: ""),
                    shortInstruction: instruction(for: turn.direction, street: "", exit: ""),
                    along: turn.along
                )
            }
        }
        return result.sorted { $0.along < $1.along }
    }

    /// How a level change is made: MOTIS says stairs or lift for some, and the station's
    /// mapped stairs / escalators / lifts right there fill in the rest.
    private enum LevelMeans {
        case stairs, escalator, elevator, unknown

        init(direction: Direction, at coordinate: CLLocationCoordinate2D?, access: [StationLayout.Access]) {
            let nearby = coordinate.map { here in
                access
                    .map { ($0.kind, here.distance(to: $0.coordinate)) }
                    .filter { $0.1 < 20 }
                    .sorted { $0.1 < $1.1 }
            } ?? []
            let kinds = nearby.map(\.0)
            switch direction {
            case .elevator:
                self = .elevator
            case .stairs:
                // escalators are mapped as conveying stairs and MOTIS only says "stairs";
                // they often run side by side, so only an escalator on its own counts
                self = kinds.contains(.escalator) && !kinds.contains(.stairs) ? .escalator : .stairs
            default:
                // wheelchair routes get an explicit lift step from MOTIS: on foot, a lift
                // right there is only the answer when there are no stairs nor escalator
                switch kinds.first(where: { $0 != .elevator }) ?? kinds.first {
                case .stairs: self = .stairs
                case .escalator: self = .escalator
                case .elevator: self = .elevator
                case nil: self = .unknown
                }
            }
        }
    }

    private static func levelInstruction(means: LevelMeans, up: Bool, target: String?) -> String {
        switch (means, up, target) {
        case (.elevator, _, let target?): return String(localized: "Prenez l'ascenseur jusqu'à \(target)")
        case (.elevator, _, nil): return String(localized: "Prenez l'ascenseur")
        case (.stairs, true, let target?): return String(localized: "Montez les escaliers vers \(target)")
        case (.stairs, true, nil): return String(localized: "Montez les escaliers")
        case (.stairs, false, let target?): return String(localized: "Descendez les escaliers vers \(target)")
        case (.stairs, false, nil): return String(localized: "Descendez les escaliers")
        case (.escalator, true, let target?): return String(localized: "Montez par l'escalier roulant vers \(target)")
        case (.escalator, true, nil): return String(localized: "Montez par l'escalier roulant")
        case (.escalator, false, let target?): return String(localized: "Descendez par l'escalier roulant vers \(target)")
        case (.escalator, false, nil): return String(localized: "Descendez par l'escalier roulant")
        case (_, true, let target?): return String(localized: "Montez vers \(target)")
        case (_, true, nil): return String(localized: "Montez au niveau supérieur")
        case (_, false, let target?): return String(localized: "Descendez vers \(target)")
        case (_, false, nil): return String(localized: "Descendez au niveau inférieur")
        }
    }

    private static func levelSymbol(means: LevelMeans, up: Bool) -> String {
        switch means {
        case .elevator: return "arrow.up.arrow.down.square"
        case .stairs, .escalator: return "figure.stairs"
        case .unknown: return up ? "arrow.up.forward.circle" : "arrow.down.forward.circle"
        }
    }

    static func geometricTurns(on path: RoutePath) -> [(along: CLLocationDistance, direction: Direction)] {
        guard path.length >= 30 else { return [] }

        func turn(at along: CLLocationDistance, window: CLLocationDistance) -> Double {
            guard let before = path.coordinate(at: along - window),
                  let here = path.coordinate(at: along),
                  let after = path.coordinate(at: along + window),
                  before.distance(to: here) > 2, here.distance(to: after) > 2 else { return 0 }
            return Angle360.delta(from: before.bearing(to: here), to: here.bearing(to: after))
        }

        var clusters: [[(along: Double, angle: Double)]] = []
        for along in path.cumulative where along >= 12 && along <= path.length - 12 {
            let angle = turn(at: along, window: 15)
            guard abs(angle) >= 30 else { continue }
            if let last = clusters.last?.last, along - last.along < 18 {
                clusters[clusters.count - 1].append((along, angle))
            } else {
                clusters.append([(along, angle)])
            }
        }

        var kept: [(along: Double, angle: Double)] = []
        for cluster in clusters {
            guard let peak = cluster.max(by: { abs($0.angle) < abs($1.angle) }) else { continue }
            let angle = turn(at: peak.along, window: 25)
            if abs(angle) >= 30 { kept.append((peak.along, angle)) }
        }

        var result: [(along: CLLocationDistance, direction: Direction)] = []
        var index = 0
        while index < kept.count {
            if index + 1 < kept.count,
               kept[index + 1].along - kept[index].along < 25,
               kept[index].angle * kept[index + 1].angle < 0,
               abs(kept[index].angle + kept[index + 1].angle) < 30 {
                index += 2
                continue
            }
            result.append((kept[index].along, direction(for: kept[index].angle)))
            index += 1
        }
        return result
    }

    private static func direction(for angle: Double) -> Direction {
        let right = angle > 0
        switch abs(angle) {
        case 160...: return right ? .uturnRight : .uturnLeft
        case 120..<160: return right ? .hardRight : .hardLeft
        case 55..<120: return right ? .right : .left
        default: return right ? .slightlyRight : .slightlyLeft
        }
    }

    static func maneuvers(for steps: [MKRoute.Step], on path: RoutePath) -> [WalkManeuver] {
        let usable = steps.filter { !$0.instructions.isEmpty && $0.polyline.pointCount > 0 }
        let starts = usable.map { $0.polyline.points()[0].coordinate }
        let positions = path.projectSequence(starts)
        return zip(usable, positions).compactMap { step, along in
            guard along > 1 else { return nil }
            return WalkManeuver(
                symbolName: symbol(forInstruction: step.instructions),
                instruction: step.instructions,
                shortInstruction: step.instructions,
                along: along
            )
        }
    }

    static func symbol(for direction: Direction) -> String {
        switch direction {
        case .depart: return "figure.walk"
        case .hardLeft, .left: return "arrow.turn.up.left"
        case .slightlyLeft: return "arrow.up.left"
        case .continueStraight: return "arrow.up"
        case .slightlyRight: return "arrow.up.right"
        case .right, .hardRight: return "arrow.turn.up.right"
        case .circleClockwise: return "arrow.clockwise.circle"
        case .circleCounterClockwise: return "arrow.counterclockwise.circle"
        case .stairs: return "figure.stairs"
        case .elevator: return "arrow.up.arrow.down.square"
        case .uturnLeft: return "arrow.uturn.left"
        case .uturnRight: return "arrow.uturn.right"
        }
    }

    static func instruction(for direction: Direction, street: String, exit: String) -> String {
        let hasStreet = !street.isEmpty
        switch direction {
        case .depart, .continueStraight:
            return hasStreet ? String(localized: "Continuez sur \(street)") : String(localized: "Continuez tout droit")
        case .left:
            return hasStreet ? String(localized: "Tournez à gauche sur \(street)") : String(localized: "Tournez à gauche")
        case .hardLeft:
            return hasStreet ? String(localized: "Tournez franchement à gauche sur \(street)") : String(localized: "Tournez franchement à gauche")
        case .slightlyLeft:
            return hasStreet ? String(localized: "Serrez à gauche sur \(street)") : String(localized: "Serrez à gauche")
        case .right:
            return hasStreet ? String(localized: "Tournez à droite sur \(street)") : String(localized: "Tournez à droite")
        case .hardRight:
            return hasStreet ? String(localized: "Tournez franchement à droite sur \(street)") : String(localized: "Tournez franchement à droite")
        case .slightlyRight:
            return hasStreet ? String(localized: "Serrez à droite sur \(street)") : String(localized: "Serrez à droite")
        case .circleClockwise, .circleCounterClockwise:
            if !exit.isEmpty {
                return String(localized: "Au rond-point, prenez la sortie \(exit)")
            }
            return String(localized: "Traversez le rond-point")
        case .stairs:
            return String(localized: "Prenez les escaliers")
        case .elevator:
            return String(localized: "Prenez l'ascenseur")
        case .uturnLeft, .uturnRight:
            return String(localized: "Faites demi-tour")
        }
    }

    static func symbol(forInstruction text: String) -> String {
        let text = text.lowercased()
        let slight = text.contains("slight") || text.contains("légèrement") || text.contains("serrez")
        if text.contains("u-turn") || text.contains("demi-tour") { return "arrow.uturn.left" }
        if text.contains("roundabout") || text.contains("rond-point") { return "arrow.clockwise.circle" }
        if text.contains("left") || text.contains("gauche") { return slight ? "arrow.up.left" : "arrow.turn.up.left" }
        if text.contains("right") || text.contains("droite") { return slight ? "arrow.up.right" : "arrow.turn.up.right" }
        if text.contains("stairs") || text.contains("escalier") { return "figure.stairs" }
        return "arrow.up"
    }
}

extension Leg {
    var isTransit: Bool { mode != .walk && mode != .bike && mode != .car && mode != .rental && mode != .carParking }

    var allStops: [Place] {
        [from] + (intermediateStops ?? []) + [to]
    }

    var departureDelayMinutes: Int {
        guard realTime else { return 0 }
        return Int((startTime.timeIntervalSince(scheduledStartTime) / 60).rounded())
    }

    var arrivalDelayMinutes: Int {
        guard realTime else { return 0 }
        return Int((endTime.timeIntervalSince(scheduledEndTime) / 60).rounded())
    }

    var spokenLineName: String {
        let line = routeShortName ?? headsign ?? ""
        let kind: String
        switch mode {
        case .tram: kind = String(localized: "le tram")
        case .ferry: kind = String(localized: "le bateau")
        case .subway, .metro: kind = String(localized: "le métro")
        case .funicular: kind = String(localized: "le funiculaire")
        case .bus, .coach: kind = String(localized: "le bus")
        default: kind = mode.isRail ? String(localized: "le train") : String(localized: "la ligne")
        }
        return line.isEmpty ? kind : "\(kind) \(line)"
    }
}
