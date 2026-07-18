//
//  ExpandedStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct ExpandedStopView: View {
    @StateObject private var viewModel: StopViewModel
    @State var selectedDate = Date()
    @State private var showDatePicker = false
    @State private var contentTransitionId = UUID()
    @State private var animateIn = false
    @State private var isChangingContent = false
    @State private var showContent = true
    @State private var viewType = String(localized: "Groupé")
    @Namespace private var animation
    let maxGroupsToShow: Int
    
    init(stop: SearchResult, fromStops: Bool, maxGroupsToShow: Int, time: Date? = nil) {
        self._viewModel = StateObject(wrappedValue: StopViewModel(stop: stop, fromStops: fromStops, time: time))
        self.maxGroupsToShow = maxGroupsToShow
        self._selectedDate = State(initialValue: time ?? Date())
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ExpandedStopHeaderView(
                    showDatePicker: $showDatePicker,
                    animateIn: $animateIn,
                    selectedDate: $selectedDate,
                    viewType: $viewType,
                    onDateSelected: {
                        contentTransition {
                            await loadDeparturesForSelectedTime()
                        }
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                
                ZStack {
                    if viewModel.isLoading {
                        StopContentLoadingView(animateIn: $animateIn, errorMessage: viewModel.errorMessage)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.routeGroups.isEmpty && !viewModel.isLoading {
                        StopContentEmptyView(animateIn: $animateIn, errorMessage: viewModel.errorMessage)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if showContent {
                        RouteGroupsView(
                            viewModel: viewModel,
                            animateIn: $animateIn,
                            maxGroupsToShow: maxGroupsToShow,
                            animation: animation,
                            viewType: $viewType,
                            selectedDate: $selectedDate
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    }
                }
                .id(contentTransitionId)
                
            }
        }
        .onAppear {
            viewModel.startMonitoring()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateIn = true
            }
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
    
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
    
    private func loadDeparturesForSelectedTime() async {
        await viewModel.refreshDepartures(forTime: selectedDate, showLoading: true)
    }
}
