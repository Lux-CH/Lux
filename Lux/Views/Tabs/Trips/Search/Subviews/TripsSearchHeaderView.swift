//
//  TripsSearchHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 26.07.2025.
//

import SwiftUI

struct TripsSearchHeaderView: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @FocusState.Binding var isFromFocused: Bool
    @FocusState.Binding var isToFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSwapping = false
    @State private var showTimePicker = false
    var onBack: (() -> Void)?
    
    var body: some View {
        ZStack(alignment: .top) {
            headerBackground
            
            VStack(alignment: .center, spacing: 20) {
                HStack(spacing: 14) {
                    RouteIndicatorView(onBack: onBack)
                    
                    VStack(spacing: 18) {
                        HStack {
                            fromSearchBar
                            HStack(spacing: 8) {
                                timeButton
                                settingsButton
                            }
                            .padding(.leading, 8)
                        }
                        
                        HStack {
                            toSearchBar
                            swapButton
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 20)
        }
        .ignoresSafeArea(edges: .top)
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                colorScheme == .dark
                    ? Color(.secondarySystemBackground).opacity(0.8)
                    : Color.white
            )
            .frame(height: 205)
            .clipShape(
                .rect(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: 40,
                    bottomTrailingRadius: 40,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08),
                radius: 15,
                x: 0,
                y: 5
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.departureType)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.showTripResults)
    }
    
    private var fromSearchBar: some View {
        TripSearchBar(
            searchText: $viewModel.fromQuery,
            isFocused: $isFromFocused,
            placeholderText: "Depuis",
            selectedLocation: viewModel.selectedFrom,
            onSearch: { viewModel.performSearch(viewModel.fromQuery) },
            onClear: { viewModel.resetSearch() },
            onRemoveTag: {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeFromLocation()
                }
            },
            iconName: "location"
        )
        .onTapGesture {
            if viewModel.selectedFrom == nil {
                isFromFocused = true
                viewModel.setActiveSearchField(.from)
            }
        }
        .onChange(of: isFromFocused) {
            if isFromFocused {
                viewModel.setActiveSearchField(.from)
            }
        }
    }
    
    private var toSearchBar: some View {
        TripSearchBar(
            searchText: $viewModel.toQuery,
            isFocused: $isToFocused,
            placeholderText: "À",
            selectedLocation: viewModel.selectedTo,
            onSearch: { viewModel.performSearch(viewModel.toQuery) },
            onClear: { viewModel.resetSearch() },
            onRemoveTag: {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeToLocation()
                }
            },
            iconName: "mappin"
        )
        .onTapGesture {
            if viewModel.selectedTo == nil {
                isToFocused = true
                viewModel.setActiveSearchField(.to)
            }
        }
        .onChange(of: isToFocused) {
            if isToFocused {
                viewModel.setActiveSearchField(.to)
            }
        }
    }
    
    private var swapButton: some View {
        Button(action: {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                isSwapping = true
                viewModel.swapLocations()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isSwapping = false
                }
            }
        }) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(swapButtonForegroundColor)
                .frame(width: 42, height: 42)
                .background(buttonBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(buttonBorderColor, lineWidth: 0.5)
                )
                .rotationEffect(isSwapping ? Angle(degrees: 180) : .zero)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isSwapping)
                .scaleEffect(isSwapping ? 0.95 : 1.0)
        }
        .disabled(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $viewModel.showSettings) {
            RouteOptionsView(routeOptions: viewModel.routeOptions) { newOptions in
                viewModel.updateRouteOptions(newOptions)
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private var timeButton: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            showTimePicker = true
        }) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 42, height: 42)
                .background(buttonBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(buttonBorderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .popover(isPresented: $showTimePicker) {
            TripsSearchTimePickerView(
                selectedDate: $viewModel.selectedDate,
                departureType: $viewModel.departureType,
                showDatePicker: $showTimePicker
            ) {
                viewModel.changeDepartureType(viewModel.departureType)
            }
            .presentationCompactAdaptation(.popover)
        }
    }
    
    private var settingsButton: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            viewModel.showSettings = true
        }) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 42, height: 42)
                .background(buttonBackground)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(buttonBorderColor, lineWidth: 0.5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var buttonBackground: some View {
        Circle()
            .fill(Color(.secondarySystemFill).opacity(0.5))
    }
    
    private var buttonBorderColor: Color {
        Color.primary.opacity(0.1)
    }
    
    private var swapButtonForegroundColor: Color {
        let isEnabled = !(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
        return isEnabled ? .accentColor : Color(.tertiaryLabel)
    }
}

struct RouteIndicatorView: View {
    var onBack: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 22) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 14, height: 14)
            
            ForEach(0..<3) { index in
                Circle()
                    .fill(index != 1 ? Color.gray.opacity(0.5) : Color.clear)
                    .frame(width: 4, height: 4)
                    .overlay(alignment: .center) {
                        if index == 1 {
                            backButton
                        }
                    }
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.8))
                .frame(width: 14, height: 14)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var backButton: some View {
        Button(action: { onBack?() }) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 12, height: 12)
                .foregroundColor(.accentColor)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color(.secondarySystemFill).opacity(0.5))
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
        .padding(.leading, 2)
        .transition(.opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.9)))
    }
}
