//
//  ExpandedStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom
import Combine

struct ExpandedStopView: View {
    @StateObject private var viewModel: StopViewModel
    @State private var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var isLoadingEarlier = false
    @State private var isLoadingLater = false
    @State private var contentTransitionId = UUID()
    @State private var animateIn = false
    @State private var isChangingContent = false
    @State private var showContent = true
    @State private var showFloatingControls = false
    @Namespace private var animation
    let maxGroupsToShow: Int
    
    init(stop: SearchResult, maxGroupsToShow: Int) {
        self._viewModel = StateObject(wrappedValue: StopViewModel(stop: stop, fromStops: true))
        self.maxGroupsToShow = maxGroupsToShow
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                ExpandedStopHeaderView(
                    showDatePicker: $showDatePicker,
                    animateIn: $animateIn,
                    selectedDate: $selectedDate,
                    onDateSelected: {
                        contentTransition {
                            await loadDeparturesForSelectedTime()
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                
                // Content
                ZStack {
                    if viewModel.isLoading {
                        StopContentLoadingView(animateIn: $animateIn, errorMessage: viewModel.errorMessage)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    } else if viewModel.routeGroups.isEmpty && !viewModel.isLoading {
                        StopContentEmptyView(animateIn: $animateIn, errorMessage: viewModel.errorMessage)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    } else if showContent {
                        RouteGroupsView(
                            viewModel: viewModel,
                            animateIn: $animateIn,
                            maxGroupsToShow: maxGroupsToShow,
                            animation: animation
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
                .id(contentTransitionId)
                
                Spacer(minLength: 80)
            }
            
            // Pagination ctrls
            if showFloatingControls {
                PaginationControlsView(
                    isLoadingEarlier: $isLoadingEarlier,
                    isLoadingLater: $isLoadingLater,
                    isChangingContent: $isChangingContent,
                    isLoading: viewModel.isLoading,
                    animateIn: $animateIn,
                    loadEarlier: {
                        contentTransition {
                            isLoadingEarlier = true
                            await loadEarlierDepartures()
                            isLoadingEarlier = false
                        }
                    },
                    loadLater: {
                        contentTransition {
                            isLoadingLater = true
                            await loadLaterDepartures()
                            isLoadingLater = false
                        }
                    }
                )
            }
        }
        .onAppear {
            viewModel.startMonitoring()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showFloatingControls = true
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animateIn = true
            }
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .onChange(of: viewModel.isLoading) {
            if !viewModel.isLoading && !viewModel.routeGroups.isEmpty {
                withAnimation {
                    showFloatingControls = true
                }
            }
        }
    }
    
    // MARK: - Sequential Animation Helper
    private func contentTransition(task: @escaping () async -> Void) {
        guard !isChangingContent else { return }
        
        isChangingContent = true
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            contentTransitionId = UUID()
            
            Task {
                await task()
                
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showContent = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isChangingContent = false
                    }
                }
            }
        }
    }
    
    // MARK: - API Methods
    private func loadDeparturesForSelectedTime() async {
        await viewModel.refreshDepartures(forTime: selectedDate, showLoading: true)
    }
    
    private func loadEarlierDepartures() async {
        guard let stopTimes = viewModel.stopTimes else { return }
        await viewModel.loadPaginatedDepartures(cursor: stopTimes.previousPageCursor)
    }
    
    private func loadLaterDepartures() async {
        guard let stopTimes = viewModel.stopTimes else { return }
        await viewModel.loadPaginatedDepartures(cursor: stopTimes.nextPageCursor)
    }
}
