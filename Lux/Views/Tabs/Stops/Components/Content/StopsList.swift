//
//  StopsList.swift
//  Lux
//
//  Created by Constantin Clerc on 20.04.2025.
//

import SwiftUI
import LuxCom

struct StopsList: View {
    let stops: [SearchResult]
    let locationManager: LocationManager
    let isSearching: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(stops) { stop in
                    NavigationLink(destination: IndividualStopView(stop: stop)) {
                        StopRowView(
                            stop: stop,
                            locationManager: locationManager,
                            isSearching: isSearching
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if stop.id != stops.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Spacer().frame(height: 85)
        }
    }
}
