//
//  IndividualStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom

struct IndividualStopView: View {
    @State var stop : SearchResult
    var body: some View {
        ZStack {
            Color(.black)
                .ignoresSafeArea()
                .opacity(0.9)
            
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground).opacity(0.8))
                        .frame(maxHeight: .infinity)
                        .frame(height: 175)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 40,
                                bottomTrailingRadius: 40,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                    
                    StopHeaderView(stop: stop)
                        .padding(.top, 95)
                        .padding(.horizontal, 20)
                }
                .ignoresSafeArea(edges: .top)
                ZStack {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground).opacity(0.8))
                        .frame(maxHeight: .infinity)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 38,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 38,
                                style: .continuous
                            )
                        )
                    
                    VStack(alignment: .center) {
                        StopView(stop: stop, maxGroupsToShow: 15, fromStops: true)
                        Spacer()
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

//#Preview {
//    IndividualStopView()
//}
