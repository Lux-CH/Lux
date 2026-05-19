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
    let forceLC: Bool
    
    init(
        stop: SearchResult,
        maxGroupsToShow: Int,
        fromStops: Bool,
        dontShowLastDivider: Bool = true,
        isLastStopOverall: Bool = false,
        forceLC: Bool = false
    ) {
        self.stop = stop
        self.maxGroupsToShow = maxGroupsToShow
        self.fromStops = fromStops
        self.dontShowLastDivider = dontShowLastDivider
        self.isLastStopOverall = isLastStopOverall
        self.forceLC = forceLC
    }
    
    var body: some View {
        if fromStops {
            ExpandedStopView(
                stop: stop,
                fromStops: true,
                forceLC: forceLC,
                maxGroupsToShow: maxGroupsToShow
            )
        } else {
            CompactStopView(
                stop: stop,
                maxGroupsToShow: maxGroupsToShow,
                dontShowLastDivider: dontShowLastDivider,
                isLastStopOverall: isLastStopOverall,
                forceLC: forceLC
            )
        }
    }
}
