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
            
            VStack(spacing: 22.5) {
                topBar
                inputCard
            }
            .padding(.top, 47.5)
            .padding(.horizontal, 16)
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $viewModel.showSettings) {
            RouteOptionsView(routeOptions: viewModel.routeOptions) { newOptions in
                viewModel.updateRouteOptions(newOptions)
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                Color.clear
            )
            .frame(height: 225)
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
    
    private var topBar: some View {
        HStack(spacing: 8) {
            if onBack != nil {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxHeight: 15)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .foregroundColor(.accentColor)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(.secondarySystemFill).opacity(0.5))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            Spacer()
            
            timeChip
            
            optionsChip
        }
        .padding(.horizontal, 4)
    }
    
    private var timeChip: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            showTimePicker = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .semibold))
                if viewModel.selectedDate != nil {
                    Text(timeSummaryText)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
            }
            .foregroundColor(.accentColor)
            .frame(maxHeight: 15)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.05 : 0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Heure de \(viewModel.departureType == .arriveBy ? "d'arrivée" : "départ"): \(timeSummaryText)")
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
    
    private var optionsChip: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            viewModel.showSettings = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.accentColor)
            .frame(maxHeight: 15)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.05 : 0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Options d'itinéraire")
    }
    
    private var inputCard: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemFill).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
            
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "location")
                        .foregroundStyle(viewModel.selectedFrom == nil ? .secondary : Color.accent)
                        .frame(width: 20)
                    fromSearchBar
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 12)
                
                Divider()
                
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(viewModel.selectedTo == nil ? .secondary : Color.accent)
                        .frame(width: 20)
                    toSearchBar
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 12)
            }
            
            swapButton
                .padding(.trailing, 6)
        }
        .frame(height: 98)
    }
    
    private var fromSearchBar: some View {
        TripSearchBar(
            searchText: $viewModel.fromQuery,
            isFocused: $isFromFocused,
            placeholderText: String(localized:"Depuis"),
            selectedLocation: viewModel.selectedFrom,
            onSearch: { viewModel.performSearch(viewModel.fromQuery) },
            onClear: { viewModel.resetSearch() },
            onRemoveTag: {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeFromLocation()
                }
            }
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
            placeholderText: String(localized:"À"),
            selectedLocation: viewModel.selectedTo,
            onSearch: { viewModel.performSearch(viewModel.toQuery) },
            onClear: { viewModel.resetSearch() },
            onRemoveTag: {
                withAnimation(.spring(response: 0.4)) {
                    viewModel.removeToLocation()
                }
            }
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
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(Color(.secondarySystemFill).opacity(0.5))
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                )
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .rotationEffect(isSwapping ? Angle(degrees: 180) : .zero)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isSwapping)
                .scaleEffect(isSwapping ? 0.95 : 1.0)
        }
        .disabled(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Inverser le champ De et le champ À")
    }
    
    private var swapButtonForegroundColor: Color {
        let isEnabled = !(viewModel.selectedFrom == nil && viewModel.selectedTo == nil)
        return isEnabled ? .accentColor : Color(.tertiaryLabel)
    }
    
    private var timeSummaryText: String {
        let typeText = viewModel.departureType == .arriveBy
        ? String(localized: "Arrivée")
        : String(localized: "Départ")
        
        if let date = viewModel.selectedDate {
            let dateText = Self.formatDate(date)
            return "\(typeText) • \(dateText)"
        } else {
            return "\(typeText) \(String(localized: "Maintenant"))"
        }
    }
    
    private static func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            return timeOnlyFormatter.string(from: date)
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
            let timeString = timeOnlyFormatter.string(from: date)
            return "\(timeString)*"
        } else {
            return dateAndTimeFormatter.string(from: date)
        }
    }
    
    private static let timeOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .autoupdatingCurrent
        df.timeStyle = .short
        return df
    }()
    
    private static let dateAndTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .autoupdatingCurrent
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}
