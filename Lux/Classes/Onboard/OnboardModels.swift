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
    static func maneuvers(for steps: [StepInstruction], on path: RoutePath) -> [WalkManeuver] {
        guard !path.isEmpty else { return [] }

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
