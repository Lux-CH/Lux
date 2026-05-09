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
    @ObservedObject var locationManager: LocationManager
    let isSearching: Bool
    
    private var uniqueStops: [SearchResult] {
        var seen = Set<String>()
        return stops.filter { stop in
            guard !seen.contains(stop.id) else {
                return false
            }
            seen.insert(stop.id)
            return true
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(uniqueStops) { stop in
                    NavigationLink(destination: IndividualStopView(stop: stop)) {
                        StopRowView(
                            stop: stop,
                            locationManager: locationManager,
                            isSearching: isSearching
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if stop.id != uniqueStops.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Spacer().frame(height: 100)
        }
    }
}
