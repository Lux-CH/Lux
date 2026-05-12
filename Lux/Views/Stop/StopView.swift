//
//  StopView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct StopView: View {
    let stop: SearchResult
    let maxGroupsToShow: Int
    let fromStops: Bool
    let dontShowLastDivider: Bool
    let isLastStopOverall: Bool
    
    init(
        stop: SearchResult,
        maxGroupsToShow: Int,
        fromStops: Bool,
        dontShowLastDivider: Bool = true,
        isLastStopOverall: Bool = false
    ) {
        self.stop = stop
        self.maxGroupsToShow = maxGroupsToShow
        self.fromStops = fromStops
        self.dontShowLastDivider = dontShowLastDivider
        self.isLastStopOverall = isLastStopOverall
    }
    
    var body: some View {
        if fromStops {
            ExpandedStopView(viewModel: StopViewModel(stop: stop, fromStops: true), maxGroupsToShow: maxGroupsToShow)
        } else {
            CompactStopView(stop: stop, maxGroupsToShow: maxGroupsToShow, dontShowLastDivider: dontShowLastDivider, isLastStopOverall: isLastStopOverall)
        }
    }
}
