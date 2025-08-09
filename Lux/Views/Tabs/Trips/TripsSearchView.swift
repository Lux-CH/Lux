//
//  TripsSearchView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//

import SwiftUI
import LuxCom

struct TripsSearchView: View {
    @StateObject private var viewModel = TripsSearchViewModel()
    @EnvironmentObject var locationManager: LocationManager
    @FocusState private var isFromFocused: Bool
    @FocusState private var isToFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) var dismiss
    @State private var dragOffset: CGFloat = 0

    var initialSearchResult: SearchResult? = nil
    var initialTargetField: TripsSearchViewModel.SearchField = .to

    var body: some View {
        NavigationStack {
            GeometryReader {_ in
                ZStack {
                    LinearGradient(
                        colors: colorScheme == .dark
                        ? [Color(.systemBackground), Color(.systemBackground).opacity(0.92)]
                        : [Color(.secondarySystemBackground).opacity(0.7), Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    .gesture(dragGesture)
                    
                    VStack(spacing: -15) {
                        TripsSearchHeaderView(
                            viewModel: viewModel,
                            isFromFocused: $isFromFocused,
                            isToFocused: $isToFocused,
                            isFromStop: true,
                            onBack: { dismiss() }
                        )
                        .gesture(dragGesture)
                        .ignoresSafeArea(.keyboard)
                        
                        TripsSearchContentView(viewModel: viewModel)
                        .offset(y: max(0, dragOffset))
                        .animation(.interactiveSpring(), value: dragOffset)
                        .gesture(dragGesture)
                        .ignoresSafeArea(.keyboard)
                    }
                }
            }
            .keyboardToolbar {
                ShortcutsKeyboardToolbar(
                    onShortcutSelected: { result in
                        let targetField: TripsSearchViewModel.SearchField = isFromFocused ? .from : .to
                        viewModel.handleInitialSearchResult(result, targetField: targetField)
                    },
                    onCurrentPositionSelected: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            viewModel.selectCurrentPosition()
                            HapticFeedback.lightImpact()
                        }
                    }
                )
            }
        }
        .onAppear {
            viewModel.setupLocationManager(locationManager)
            if let result = initialSearchResult {
                Task { @MainActor in
                    viewModel.handleInitialSearchResult(result, targetField: initialTargetField)
                }
            }
        }
        .onChange(of: viewModel.fromQuery) {
            viewModel.onChange(of: viewModel.fromQuery)
        }
        .onChange(of: viewModel.toQuery) {
            viewModel.onChange(of: viewModel.toQuery)
        }
    }
    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                if value.translation.height > 200 {
                    dismiss()
                } else {
                    dragOffset = 0
                }
            }
    }
}
