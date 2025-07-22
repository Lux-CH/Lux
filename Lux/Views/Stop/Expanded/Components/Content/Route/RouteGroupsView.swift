//
//  RouteGroupsView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct RouteGroupsView: View {
    @ObservedObject var viewModel: StopViewModel
    @Binding var animateIn: Bool
    let maxGroupsToShow: Int
    var animation: Namespace.ID
    @Binding var viewType: String
    @Binding var selectedDate: Date
    
    var body: some View {
        if viewType == "Groupé" {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    let shownRoutes = Array(viewModel.routeNames.prefix(maxGroupsToShow))
                    ForEach(Array(shownRoutes.enumerated()), id: \.element) { index, routeName in
                        if let groups = viewModel.routeGroups[routeName], !groups.isEmpty {
                            RouteGroupView(
                                routeName: routeName,
                                groups: groups,
                                viewModel: viewModel,
                                animateIn: $animateIn,
                                animation: animation,
                                isLastRoute: routeName == shownRoutes.last
                            )
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : 20)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(Double(index) * 0.1 + 0.2), value: animateIn)
                        }
                    }
                }
                .padding(.bottom, 10)
            }
            .refreshable {
                await refresh()
            }
        } else if let stopTimes = viewModel.stopTimes?.stopTimes {
            List(viewModel.sortStopTimes(stopTimes)) { stopTime in
                ExpandedDepartureRowView(stopTime: stopTime) { routeShortName in
                    viewModel.userSelectedLine(routeShortName)
                }
                .listRowBackground(Color(.secondarySystemBackground).opacity(0.1))
            }
            .listStyle(.plain)
            .padding(.bottom, 10)
            .refreshable {
                await refresh()
            }
        }
    }
    private func refresh() async {
        let now = Date()
        await viewModel.refreshDepartures(forTime: now, showLoading: false)
        selectedDate = now
    }
}
