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
    @State private var showWarningOvertimeAlert = false
    @State var isFromStop: Bool = false
    @State private var headerOffset: CGFloat = -100
    @State private var contentOpacity: Double = 0
    var onBack: (() -> Void)?

    
    private var statusBarSpacing: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 48
        return max(topInset - 8, 48)
    }
    var body: some View {
        ZStack(alignment: .top) {
            headerBackground

            VStack(spacing: 22.5) {
                topBar
                    .opacity(contentOpacity)
                inputCard
                    .opacity(contentOpacity)
            }
            .padding(.top, statusBarSpacing)
            .padding(.horizontal, 16)
            .offset(y: headerOffset)
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.1)) {
                headerOffset = 0
                contentOpacity = 1.0
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            RouteOptionsView(routeOptions: viewModel.routeOptions) { newOptions in
                viewModel.updateRouteOptions(newOptions)
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(36)
        }
    }
    
    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                isFromStop ? (colorScheme == .dark
                ? Color(.secondarySystemBackground).opacity(0.8)
                : Color.white) : Color.clear
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
    
    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 8) {
            if onBack != nil {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        headerOffset = -80
                        contentOpacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onBack?()
                    }
                }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxHeight: 15)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 20)
                        .foregroundColor(.accentColor)
                        .contentShape(Capsule(style: .continuous))
                        .clipShape(Capsule(style: .continuous))
                        .adaptable(ios26: .glassButtonClear, fallback: {
                            $0.background(
                                Capsule(style: .continuous)
                                    .fill(Color(.secondarySystemFill).opacity(0.5))
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                            
                        })
                }
                .buttonStyle(ScaleButtonStyle())
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .move(edge: .leading)).combined(with: .scale(scale: 0.8))
                ))
            }
            
            Spacer()
            
            GlassEffectGroup(spacing: 6) {
                HStack {
                    if viewModel.selectedDate ?? Date() < Date().addingTimeInterval(-10 * 60) {
                        warningTimeChip
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8)),
                                removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8))
                            ))
                    }
                    
                    timeChip
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .move(edge: .top)).combined(with: .scale(scale: 0.8))
                        ))
                    
                    optionsChip
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.8)),
                            removal: .opacity.combined(with: .move(edge: .trailing)).combined(with: .scale(scale: 0.8))
                        ))
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    @ViewBuilder
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
            .contentShape(Capsule(style: .continuous))
            .clipShape(Capsule(style: .continuous))
            .adaptable(ios26: .glassButtonTinted(Color.accentColor.opacity(0.12)), fallback: {
                $0.background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
                )
            })
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Heure de \(viewModel.departureType == .arriveBy ? "d'arrivée" : "départ"): \(timeSummaryText)")
        .popover(isPresented: $showTimePicker) {
            TripsSearchTimePickerView(
                selectedDate: $viewModel.selectedDate,
                departureType: $viewModel.departureType,
                showDatePicker: $showTimePicker
            ) {
                if viewModel.selectedFrom != nil && viewModel.selectedTo != nil {
                    viewModel.searchTrips()
                }
            }
            .presentationCompactAdaptation(.popover)
        }
    }
    
    @ViewBuilder
    private var warningTimeChip: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            showWarningOvertimeAlert = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.yellow)
            .frame(maxHeight: 15)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .contentShape(Capsule(style: .continuous))
            .clipShape(Capsule(style: .continuous))
            .adaptable(ios26: .glassButtonTinted(Color.yellow.opacity(0.12)), fallback: {
                $0.background(
                    Capsule(style: .continuous)
                        .fill(Color.yellow.opacity(0.12))
                        .stroke(Color.yellow.opacity(0.35), lineWidth: 0.5)
                )
            })
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Avertissement")
        .alert("Date potentiellement incorrecte", isPresented: $showWarningOvertimeAlert) {
            Button("OK", role: .cancel) { }
            Button("Réinitialiser", role: .destructive) {viewModel.selectedDate = nil}
        } message: {
            Text("La date séléctionnée est antérieure à l'heure actuelle")
        }
    }
    
    @ViewBuilder
    private var optionsChip: some View {
        Button(action: {
            HapticFeedback.lightImpact()
            viewModel.showSettings = true
        }) {
            HStack(spacing: 6) {
                if viewModel.hasCustomSettings {
                    Image("toggled.slider.horizontal.3.badge.checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.green, Color.accentColor)
                } else {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.accentColor)
            .frame(maxHeight: 15)
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .contentShape(Capsule(style: .continuous))
            .clipShape(Capsule(style: .continuous))
            .adaptable(ios26: .glassButtonTinted(Color.accentColor.opacity(0.12)), fallback: {
                $0.background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 0.5)
                )
            })
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Options d'itinéraire")
    }
    
    private var inputCard: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemFill).opacity(0.5))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
            
            ZStack {
                connectionLine
                
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .foregroundStyle(viewModel.selectedFrom == nil ? .secondary : Color.accentColor)
                            .frame(width: 20)
                        fromSearchBar
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 12)
                    
                    Divider()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(viewModel.selectedTo == nil ? .secondary : Color.accentColor)
                            .frame(width: 20)
                        toSearchBar
                            .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 12)
                }
            }
            
            swapButton
                .padding(.trailing, 6)
        }
        .frame(height: 98)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95))
        ))
    }
    
    private var connectionLine: some View {
        VStack {
            Spacer()
            HStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                viewModel.selectedFrom == nil ? Color.secondary.opacity(0.3) : Color.accentColor.opacity(0.4),
                                viewModel.selectedTo == nil ? Color.secondary.opacity(0.3) : Color.accentColor.opacity(0.4)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 30)
                    .cornerRadius(1)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.selectedFrom)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.selectedTo)
                
                Spacer()
            }
            .padding(.leading, 20)
            Spacer()
        }
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
                .rotationEffect(isSwapping ? Angle(degrees: 180) : .zero)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isSwapping)
                .scaleEffect(isSwapping ? 0.95 : 1.0)
                .contentShape(Circle())
                .clipShape(Circle())
                .adaptable(ios26: .glassButtonClear, fallback: {
                    $0.background(
                        Circle()
                            .fill(Color(.secondarySystemFill).opacity(0.5))
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                            .background(Circle().fill(Color(.secondarySystemBackground)))
                    )
                })
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
