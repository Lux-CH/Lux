//
//  CompactStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom
import Combine

struct CompactStopView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel: StopViewModel
    let maxGroupsToShow: Int
    
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    init(stop: SearchResult, maxGroupsToShow: Int) {
        self._viewModel = StateObject(wrappedValue: StopViewModel(stop: stop, fromStops: false))
        self.maxGroupsToShow = maxGroupsToShow
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if viewModel.isLoading {
                loadingView
            } else if viewModel.routeGroups.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                routeGroupsContent
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        NavigationLink(destination: IndividualStopView(stop: viewModel.stop)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "signpost.right")
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.stop.name)
                        .multilineTextAlignment(.leading)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    connectionPills(prefix: 3)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 12)
                .padding(.top, 20)
                
                Divider()
                    .padding(.bottom, 0)
            }
            .background {
                if colorScheme == .dark {
                    MaskedImageView()
                        .edgesIgnoringSafeArea(.all)
                } else {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 38,
                        bottomLeadingRadius: 2,
                        bottomTrailingRadius: 2,
                        topTrailingRadius: 38,
                        style: .continuous
                    )
                    .strokeBorder(Color(UIColor.systemGray5), lineWidth: 1)
                    .edgesIgnoringSafeArea(.all)
                }
            }
        }
    }
    
    private func connectionPills(prefix: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(viewModel.connections.prefix(prefix), id: \.self) { connection in
                LinePill(line: connection, mode: .bus)
            }
            if viewModel.connections.count > prefix {
                MorePill()
            }
        }
    }
    
    private var loadingView: some View {
        ProgressView("Chargement des départs...")
            .padding()
            .overlay(
                Group {
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    }
                }, alignment: .bottom
            )
    }
    
    private var emptyStateView: some View {
        VStack {
            Text("Aucun départ à venir.")
                .foregroundColor(.gray)
                .padding()
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
    
    private var routeGroupsContent: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.routeNames.prefix(maxGroupsToShow), id: \.self) { routeName in
                if let groups = viewModel.routeGroups[routeName], !groups.isEmpty {
                    routeGroupView(for: routeName, groups: groups)
                }
            }
        }
    }
    
    private func routeGroupView(for routeName: String, groups: [GroupedStopTime]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottom) {
                TabView(selection: Binding(
                    get: { viewModel.currentPages[routeName] ?? 0 },
                    set: { viewModel.currentPages[routeName] = $0 }
                )) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        if !group.stopTimes.isEmpty {
                            IncomingBusView(group: group)
                                .padding(.horizontal)
                                .tag(index)
                        }
                    }
                }
                .frame(height: 70)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                paginationDotsView(groups: groups, routeName: routeName)
            }
            
            if routeName != viewModel.routeNames.prefix(maxGroupsToShow).last {
                Divider()
                    .padding(.horizontal)
            }
        }
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
