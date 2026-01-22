//
//  ExpandedDepartureRowView.swift
//  Lux
//
//  Created by Constantin Clerc on 20.07.2025.
//

import SwiftUI
import LuxCom

struct ExpandedDepartureRowView: View {
    let stopTime: StopTime
    let forceLC: Bool
    var userSelectedLine: (String) -> Void
    var body: some View {
        NavigationLink(destination: {
            ItineraryView(tripId: stopTime.tripId, fromNearby: false, forceLC: forceLC)
                .toolbarBackground(.hidden, for: .navigationBar)
                .navigationBarBackButtonHidden(true)
                .onAppear {
                    userSelectedLine(stopTime.routeShortName)
                }
        }) {
            HStack(spacing: 12) {
                LinePill(
                    line: stopTime.routeShortName,
                    mode: stopTime.mode,
                    agency: stopTime.agencyId,
                    width: 32,
                    height: 20,
                    fontSize: 13
                )
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .font(.system(size: 16))
                
                Text(stopTime.headsign ?? "Inconnu")
                    .fontWeight(.medium)
                
                Spacer()
                ArrivalMinuteView(incomingStop: stopTime, shouldAutoRefresh: true)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
