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
    let isFromMultiple: Bool
    let forceLC: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = Settings.shared
    @State private var showTripSearch: Bool = false

    private var transformedStopId: String {
        guard let stopId = stop.stopId, !stopId.contains("ch_Parent") else {
            return stop.stopId ?? ""
        }
        
        return stopId.replacingOccurrences(of: "ch_", with: "ch_Parent")
            .components(separatedBy: ":").first ?? stopId
    }

    private var shouldUsePlaceForTripSearch: Bool {
        return settings.dataSource == .cita
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
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
                .navigationDestination(isPresented: $showTripSearch) {
                    TripsSearchView(
                        initialSearchResult: generateTripSearchResult(),
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

    private func generateTripSearchResult() -> SearchResult {
        if shouldUsePlaceForTripSearch {
            return SearchResult(
                type: .place,
                tokens: [[]],
                name: stop.name,
                id: "",
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

        return generateStopSearchResult()
    }

    private func createExpandedStopView() -> some View {
        let selectedDate = stop.departure ?? stop.arrival ?? Date()
        return ExpandedStopView(viewModel: StopViewModel(stop: generateStopSearchResult(), fromStops: true, isLC: isFromMultiple || forceLC, time: selectedDate), selectedDate: selectedDate, maxGroupsToShow: 50)
            .background(Color(.secondarySystemBackground))
    }
}
