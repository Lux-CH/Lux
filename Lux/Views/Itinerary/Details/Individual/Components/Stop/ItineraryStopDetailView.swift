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
    @State private var showTripSearch: Bool = false

    private var transformedStopId: String {
        guard let stopId = stop.stopId else { return "" }
        return stopId.replacingOccurrences(of: "ch_", with: "ch_Parent")
            .components(separatedBy: ":").first ?? stopId
    }
    
    var body: some View {
        NavigationStack {
            createExpandedStopView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(stop.name)
                            .font(.headline)
                            .lineLimit(1)
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
                        initialSearchResult: generateSearchResult(),
                        initialTargetField: .to
                    )
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                }
        }
    }
    
    private func generateSearchResult() -> SearchResult {
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
        return ExpandedStopView(viewModel: StopViewModel(stop: generateSearchResult(), fromStops: true), maxGroupsToShow: 50)
            .background(Color(.secondarySystemBackground))
    }
}
