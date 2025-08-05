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
                    HStack {
                        LinePill(line: group.routeShortName, mode: group.stopTimes.first?.mode ?? .bus)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(Color.primary.opacity(0.3))
                        Text(group.headsign)
                            .fontWeight(.regular)
                            .foregroundStyle(colorScheme == .dark ? Color.white: Color.black)
                    }
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 3)
                    
                    let displayTrack = group.stopTimes.first {
                        $0.place.track != nil || $0.place.scheduledTrack != nil
                    }?.place.track ?? group.stopTimes.first?.place.scheduledTrack ?? String(localized: "inconnu")
                    
                    let transport = group.stopTimes.first?.mode.displayName ?? "Bus"
                    
                    Text("\(transport) • \(getTrackType(displayTrack))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .multilineTextAlignment(.leading)
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
