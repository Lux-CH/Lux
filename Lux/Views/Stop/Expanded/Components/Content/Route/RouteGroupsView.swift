//
//  RouteGroupsView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct RouteGroupsView: View {
    @ObservedObject var viewModel: StopViewModel
    @Binding var animateIn: Bool
    let maxGroupsToShow: Int
    var animation: Namespace.ID
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.routeNames.prefix(maxGroupsToShow).enumerated()), id: \.element) { index, routeName in
                    if let groups = viewModel.routeGroups[routeName], !groups.isEmpty {
                        RouteGroupView(
                            routeName: routeName,
                            groups: groups,
                            viewModel: viewModel,
                            animateIn: $animateIn,
                            animation: animation,
                            isLastRoute: routeName == viewModel.routeNames.prefix(maxGroupsToShow).last
                        )
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.1 + 0.2), value: animateIn)
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }
}
