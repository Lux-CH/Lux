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
    
    var body: some View {
        NavigationStack {
            createExpandedStopView(stop: stop)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(stop.name)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
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
                .transaction { transaction in
                    transaction.disablesAnimations = true
                }
        }
    }
}

func createExpandedStopView(stop: Place) -> some View {
    let searchResult = SearchResult(
        type: .stop,
        tokens: [[]],
        name: stop.name,
        id: stop.stopId ?? "",
        lat: stop.lat,
        lon: stop.lon,
        level: Double(stop.level),
        street: nil,
        houseNumber: nil,
        zip: nil,
        areas: [],
        score: 1.0
    )
    
    return ExpandedStopView(viewModel: StopViewModel(stop: searchResult, fromStops: true), maxGroupsToShow: 50)
        .background(Color(.secondarySystemBackground))
}
