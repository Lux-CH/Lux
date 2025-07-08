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
                    }?.place.track ?? group.stopTimes.first?.place.scheduledTrack ?? "inconnu"
                    
                    let transport = group.stopTimes.first?.mode.displayName ?? "Bus"
                    
                    Text("\(transport) • \(getTrackType(displayTrack))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.5))
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    if let firstStop = group.stopTimes.first {
                        ArrivalMinuteView(incomingStop: firstStop)
                    }
                    if group.stopTimes.count > 1 {
                        ArrivalMinuteView(incomingStop: group.stopTimes[1])
                    }
                }
            }
        }
    }
}

extension TransportationMode {
    var displayName: String {
        switch self {
        case .walk: return "À pied"
        case .bike: return "Vélo"
        case .rental: return "Location"
        case .car: return "Voiture"
        case .carParking: return "Parking"
        case .odm: return "ODM"
        case .transit: return "Transport en commun"
        case .tram: return "Tram"
        case .subway: return "Métro"
        case .ferry: return "Mouette"
        case .airplane: return "Avion"
        case .metro: return "Métro"
        case .bus: return "Bus"
        case .coach: return "Autocar"
        case .rail: return "Train"
        case .highSpeedRail: return "Train"
        case .longDistance: return "Train"
        case .nightRail: return "Train"
        case .regionalFastRail: return "Train"
        case .regionalRail: return "Train"
        case .other: return "Autre"
        }
    }
}
