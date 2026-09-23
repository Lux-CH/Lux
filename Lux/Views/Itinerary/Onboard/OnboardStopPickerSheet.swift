//
//  OnboardStopPickerSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 23.09.2026.
//

import SwiftUI
import CoreLocation
import LuxCom

struct OnboardStopPickerSheet: View {
    let tripLeg: Leg
    let userLocation: CLLocation?
    let onSelect: (_ boardIndex: Int, _ alightIndex: Int) -> Void
    @Environment(\.dismiss) private var dismiss

    private var stops: [Place] { tripLeg.allStops }

    private var boardIndex: Int {
        let now = Date()
        let stops = stops
        func time(_ stop: Place) -> Date? { stop.departure ?? stop.arrival }

        if let location = userLocation {
            let nearby = stops.indices
                .filter { index in
                    (time(stops[index]).map { $0 > now.addingTimeInterval(-180) } ?? true) && index < stops.count - 1
                }
                .map { ($0, CLLocation(latitude: stops[$0].lat, longitude: stops[$0].lon).distance(from: location)) }
                .filter { $0.1 < 250 }
                .min { $0.1 < $1.1 }
            if let nearby { return nearby.0 }
        }
        if let lastServed = stops.indices.last(where: { time(stops[$0]).map { $0 <= now } ?? false }), lastServed < stops.count - 1 {
            return lastServed
        }
        return 0
    }

    var body: some View {
        let board = boardIndex
        let color = getLegColor(tripLeg, brightIt: true)
        NavigationStack {
            List {
                Section {
                    ForEach(Array(stops.enumerated()).filter { $0.offset > board }, id: \.offset) { index, stop in
                        Button {
                            HapticFeedback.mediumImpact()
                            onSelect(board, index)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(index == stops.count - 1 ? color : Color.clear)
                                    .frame(width: 11, height: 11)
                                    .overlay(Circle().stroke(color, lineWidth: 2.5))
                                Text(stop.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if let time = stop.arrival ?? stop.scheduledArrival {
                                    Text(formatTime(time))
                                        .font(.subheadline.weight(.medium))
                                        .monospacedDigit()
                                        .foregroundStyle(stop.scheduledDifference() >= 2 ? .orange : .secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack(spacing: 8) {
                        LinePill(line: tripLeg.routeShortName ?? "", mode: tripLeg.mode, agency: tripLeg.agencyId, width: 38, height: 24, fontSize: 13)
                        Text("Depuis \(stops[board].name)")
                            .textCase(nil)
                            .lineLimit(1)
                    }
                } footer: {
                    Text("Lux vous guide jusqu'à votre arrêt et vous prévient quand descendre, même écran verrouillé.")
                }
            }
            .navigationTitle("Où descendez-vous ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}
