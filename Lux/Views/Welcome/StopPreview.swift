//
//  StopPreview.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI
import LuxCom

struct StopPreviewWelcomeView: View {
    @StateObject private var viewModel: StopViewModel
    
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    init(stop: SearchResult) {
        self._viewModel = StateObject(wrappedValue: StopViewModel(stop: stop, fromStops: false))
    }
    
    var body: some View {
        routeGroupsContent
            .onAppear { viewModel.startMonitoring() }
            .onDisappear { viewModel.stopMonitoring() }
    }
    
    private var routeGroupsContent: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.routeNames.prefix(2), id: \.self) { routeName in
                if let groups = viewModel.routeGroups[routeName], !groups.isEmpty {
                    routeGroupView(for: routeName, groups: groups)
                }
            }
        }
    }
    
    private func routeGroupView(for routeName: String, groups: [GroupedStopTime]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                tabView(for: routeName, groups: groups)
                paginationDotsView(groups: groups, routeName: routeName)
            }
            
            if routeName != viewModel.routeNames.prefix(2).last {
                Divider()
                    .padding(.horizontal)
            }
        }
    }
    
    private func tabView(for routeName: String, groups: [GroupedStopTime]) -> some View {
        TabView(selection: Binding(
            get: { viewModel.currentPages[routeName] ?? 0 },
            set: { viewModel.currentPages[routeName] = $0 }
        )) {
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if !group.stopTimes.isEmpty {
                    IncomingBusView(group: group, viewModel: viewModel)
                        .padding(.horizontal)
                        .tag(index)
                }
            }
        }
        .frame(height: 70)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
    
    private func paginationDotsView(groups: [GroupedStopTime], routeName: String) -> some View {
        Group {
            if groups.count > 1 {
                let currentPage = viewModel.currentPages[routeName] ?? 0
                HStack(spacing: 6) {
                    ForEach(0..<min(groups.count, 10), id: \.self) { index in
                        Circle()
                            .frame(width: 5, height: 5)
                            .foregroundColor(index == currentPage ? activeDotColor : inactiveDotColor)
                    }
                }
                .padding(.bottom, 5)
            }
        }
    }
}
