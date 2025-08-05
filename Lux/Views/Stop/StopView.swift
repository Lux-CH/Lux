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
    @State var dontShowLastDivider: Bool = true
    
    var body: some View {
        if fromStops {
            ExpandedStopView(viewModel: StopViewModel(stop: stop, fromStops: true), maxGroupsToShow: maxGroupsToShow)
        } else {
            CompactStopView(stop: stop, maxGroupsToShow: maxGroupsToShow, dontShowLastDivider: dontShowLastDivider)
        }
    }
}
