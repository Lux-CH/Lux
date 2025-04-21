//
//  IndividualStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom

struct IndividualStopView: View {
    @State var stop: SearchResult
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
                .opacity(0.9)
            
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    StopHeaderView(stop: stop)
                        .padding(.top, 95)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    Divider()
                    VStack(alignment: .center) {
                        StopView(stop: stop, maxGroupsToShow: 15, fromStops: true)
                            .padding(.top, -5)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(Color(.secondarySystemBackground).opacity(0.8))
                        .edgesIgnoringSafeArea([.bottom, .horizontal])
                )
                .clipShape(
                    ContainerRelativeShape()
                )
            }
            .edgesIgnoringSafeArea(.vertical)
        }
    }
}
