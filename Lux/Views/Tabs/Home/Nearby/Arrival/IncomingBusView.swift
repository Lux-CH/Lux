//
//  IncomingBusView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct IncomingBusView: View {
    let group: GroupedStopTime
    let viewModel: StopViewModel
    @Environment(\.colorScheme) var colorScheme
    
    private var parsedStopName: (city: String, location: String) {
        let components = group.headsign.components(separatedBy: ",")
        let city = components.first?.trimmingCharacters(in: .whitespaces) ?? group.headsign
        let location = components.count > 1 ? components[1].trimmingCharacters(in: .whitespaces) : ""
        return (city, location)
    }
    
    private var shouldUseNormalDisplay: Bool {
        parsedStopName.location.isEmpty
    }
    
    private static let genericLocationTerms: Set<String> = ["centre", "gare", "place", "douane", "gare cornavin", "p+r"]

    private var isCityReleavant: Bool {
        Self.genericLocationTerms.contains(parsedStopName.location.lowercased())
    }
    
    var body: some View {
        NavigationLink(destination: {
            if let tripId = group.stopTimes.first?.tripId {
                let otherTripOptions = group.stopTimes.prefix(10).map { stopTime in
                    TripOption(
                        id: stopTime.tripId,
                        startTime: stopTime.place.departure ?? stopTime.place.scheduledDeparture ?? stopTime.place.arrival ?? stopTime.place.scheduledArrival ?? Date()
                    )
                }
                
                ItineraryView(tripId: tripId, fromNearby: true, otherTripOptions: otherTripOptions)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                    .onAppear {
                        viewModel.userSelectedLine(group.routeShortName)
                    }
            }
        }) {
            HStack {
                VStack(alignment: .leading) {
                    let displayTrack = group.stopTimes.first {
                        $0.place.track != nil || $0.place.scheduledTrack != nil
                    }?.place.track ?? group.stopTimes.first?.place.scheduledTrack ?? ""
                    
                    HStack(spacing: 12) {
                        LinePill(line: group.routeShortName, mode: group.stopTimes.first?.mode ?? .bus, width: 45, height: 30, fontSize: 16.5)
                        VStack(alignment: .leading, spacing: 0) {
                            if shouldUseNormalDisplay {
                                HStack(spacing: 8) {
                                    Text(group.headsign)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text(displayTrack)
                                        .font(.system(size: 8))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                        .frame(width: 11, height: 11)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.secondary, lineWidth: 0.5)
                                        )
                                }
                            } else {
                                Text(parsedStopName.city)
                                    .font(.system(size: 11, weight: isCityReleavant ? .semibold : .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    Text(parsedStopName.location.capitalized)
                                        .font(.system(size: 17, weight: .medium ))
                                        .foregroundColor(.primary)
                                    
                                    Text(displayTrack)
                                        .font(.system(size: 8))
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                        .frame(width: 11, height: 11)
                                        .background(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(Color.secondary, lineWidth: 0.5)
                                        )
                                }
                            }
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 3)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let firstStop = group.stopTimes.first {
                        ArrivalMinuteView(incomingStop: firstStop)
                            .font(.system(size: 19, weight: .semibold))
                    }
                    
                    if group.stopTimes.count > 1 {
                        ArrivalMinuteView(incomingStop: group.stopTimes[1])
                            .font(.system(size: 11, weight: .regular))
                            .opacity(0.7)
                    }
                }
            }
        }
    }
}

extension TransportationMode {
    var displayName: String {
        switch self {
        case .walk: return String(localized: "À pied")
        case .bike: return String(localized: "Vélo")
        case .rental: return String(localized: "Location")
        case .car: return String(localized: "Voiture")
        case .carParking: return String(localized: "Parking")
        case .odm: return String(localized: "ODM")
        case .transit: return String(localized: "Transport en commun")
        case .tram: return String(localized: "Tram")
        case .subway: return String(localized: "Métro")
        case .ferry: return String(localized: "Mouette")
        case .airplane: return String(localized: "Avion")
        case .metro: return String(localized: "Métro")
        case .bus: return String(localized: "Bus")
        case .coach: return String(localized: "Autocar")
        case .rail: return String(localized: "Train")
        case .highSpeedRail: return String(localized: "Train")
        case .longDistance: return String(localized: "Train")
        case .nightRail: return String(localized: "Train")
        case .regionalFastRail: return String(localized: "Train")
        case .regionalRail: return String(localized: "Train")
        case .other: return String(localized: "Autre")
        }
    }
}

