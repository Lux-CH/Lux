//
//  RouteGroupView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct RouteGroupView: View {
    let routeName: String
    let groups: [GroupedStopTime]
    @ObservedObject var viewModel: StopViewModel
    @Binding var animateIn: Bool
    var animation: Namespace.ID
    var isLastRoute: Bool
    
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                TabView(selection: Binding(
                    get: { viewModel.currentPages[routeName] ?? 0 },
                    set: { newValue in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            viewModel.currentPages[routeName] = newValue
                        }
                    }
                )) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        ExpandedGroupView(group: group, viewModel: viewModel, animateIn: $animateIn, animation: animation)
                            .padding(.horizontal)
                            .tag(index)
                    }
                }
                .frame(height: 160)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                PaginationDotsView(
                    groupsCount: groups.count,
                    currentPage: viewModel.currentPages[routeName] ?? 0,
                    activeDotColor: activeDotColor,
                    inactiveDotColor: inactiveDotColor,
                    animateIn: $animateIn
                )
            }
            
            if !isLastRoute {
                Divider()
                    .padding(.horizontal)
                    .scaleEffect(x: animateIn ? 1 : 0, anchor: .leading)
                    .animation(.easeInOut(duration: 0.5).delay(0.3), value: animateIn)
            }
        }
    }
}
