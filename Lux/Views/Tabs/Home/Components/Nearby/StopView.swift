//
//  StopView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom
import Combine

struct StopView: View {
    @StateObject private var viewModel: StopViewModel
    let maxGroupsToShow: Int
    
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    init(stop: SearchResult, maxGroupsToShow: Int) {
        self._viewModel = StateObject(wrappedValue: StopViewModel(stop: stop))
        self.maxGroupsToShow = maxGroupsToShow
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    HStack {
                        Image(systemName: "signpost.right")
                        Text(viewModel.stop.name)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    HStack {
                        // for now this isn't automated
//                        LinePill(line: "80")
                        MorePill()
                    }
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 12)
                .padding(.top, 20)
                Divider()
                    .padding(.bottom, 0)
            }
            .background {
                MaskedImageView()
                    .edgesIgnoringSafeArea(.all)
            }
            if viewModel.isLoading {
                ProgressView("Chargement des départs...")
                    .padding()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            else if viewModel.routeGroups.isEmpty && !viewModel.isLoading {
                Text("Aucun départ à venir.")
                    .foregroundColor(.gray)
                    .padding()
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            else {
                VStack(spacing: 0) {
                    ForEach(viewModel.routeNames.prefix(maxGroupsToShow), id: \.self) { routeName in
                        if let groups = viewModel.routeGroups[routeName], !groups.isEmpty {
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
                                    .simultaneousGesture(DragGesture())
                                    .contentShape(Rectangle())
                                    .zIndex(10)
                                    
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
                                if routeName != viewModel.routeNames.prefix(maxGroupsToShow).last {
                                    Divider()
                                        .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

