//
//  ItineraryStopDetailView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI
import LuxCom

struct ItineraryStopDetailView: View {
    let stop: Place
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = Settings.shared
    @State private var showTripSearch: Bool = false

    private var transformedStopId: String {
        if let parentId = stop.parentId { return parentId }
        guard let stopId = stop.stopId else { return "" }
        return stopId
    }

    var body: some View {
        NavigationStack {
            createExpandedStopView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if #available(iOS 26, *) {
                        ToolbarItem(placement: .topBarLeading) {
                            Text(stop.name)
                                .font(.headline)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .sharedBackgroundVisibility(.hidden)
                    } else {
                        ToolbarItem(placement: .topBarLeading) {
                            Text(stop.name)
                                .font(.headline)
                                .lineLimit(1)
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 8) {
                            Button {
                                showTripSearch = true
                            } label: {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.body)
                            }
                            .tint(.secondary)
                            
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.body)
                            }
                            .tint(.secondary)
                        }
                    }
                }
                .navigationDestination(isPresented: $showTripSearch) {
                    TripsSearchView(
                        initialSearchResult: generateStopSearchResult(),
                        initialTargetField: .to
                    )
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                }
        }
    }
    
    private func generateStopSearchResult() -> SearchResult {
        return SearchResult(
            type: .stop,
            tokens: [[]],
            name: stop.name,
            id: transformedStopId,
            lat: stop.lat,
            lon: stop.lon,
            level: Double(stop.level),
            street: nil,
            houseNumber: nil,
            zip: nil,
            areas: [],
            score: 1.0
        )
    }

    private func createExpandedStopView() -> some View {
        let selectedDate = stop.departure ?? stop.arrival ?? Date()
        return ExpandedStopView(
            stop: generateStopSearchResult(),
            fromStops: true,
            maxGroupsToShow: 50,
            time: selectedDate
        )
        .background(Color(.secondarySystemBackground))
    }
}
