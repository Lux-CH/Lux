//
//  CompactStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI
import LuxCom

struct CompactStopView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel: StopViewModel

    let maxGroupsToShow: Int
    let dontShowLastDivider: Bool
    
    private let activeDotColor = Color.primary.opacity(0.5)
    private let inactiveDotColor = Color.secondary.opacity(0.3)
    
    init(stop: SearchResult, maxGroupsToShow: Int, dontShowLastDivider: Bool) {
        self._viewModel = StateObject(wrappedValue: StopViewModel(stop: stop, fromStops: false))
        self.maxGroupsToShow = maxGroupsToShow
        self.dontShowLastDivider = dontShowLastDivider
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
        
    private var headerView: some View {
        NavigationLink(destination: IndividualStopView(stop: viewModel.stop)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "signpost.right")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    
                    Text(viewModel.stop.name)
                        .multilineTextAlignment(.leading)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.caption)
                        .foregroundColor(Color(.tertiaryLabel))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 25)
                .padding(.bottom, 12)
                .padding(.top, 20)
                
                Divider()
                    .padding(.bottom, 0)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Arrêt \(viewModel.stop.name)")
            .accessibilityHint("Double-tapez pour voir tous les départs à cet arrêt")
            .accessibilityAddTraits(.isButton)
            .background(
                MaskedImageView()
                    .edgesIgnoringSafeArea(.all)
                    .opacity(colorScheme == .dark ? 1.0 : 0.75)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 38,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 38,
                            style: .continuous
                        )
                        .strokeBorder(Color(UIColor.separator).opacity(0.5), lineWidth: colorScheme == .dark ? 0 : 0.5)
                    )
                    .accessibilityHidden(true)
            )
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
                            IncomingBusView(group: group, viewModel: viewModel)
                                .padding(.horizontal)
                                .tag(index)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(groupAccessibilityLabel(for: group))
                                .accessibilityHint(groups.count > 1 ? "Balayez vers la gauche ou la droite pour changer de direction. Double-cliquez pour obtenir plus de détails sur le prochain départ." : "Double-cliquez pour obtenir plus de détails sur le prochain départ.")
                        }
                    }
                }
                .frame(height: 70)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.updatesFrequently)
                
                PaginationDotsView(
                    groupsCount: groups.count,
                    currentPage: viewModel.currentPages[routeName] ?? 0,
                    activeDotColor: activeDotColor,
                    inactiveDotColor: inactiveDotColor,
                    animateIn: .constant(true)
                )
                .accessibilityHidden(true)
            }
            
            if !(dontShowLastDivider && routeName == viewModel.routeNames.prefix(maxGroupsToShow).last) {
                Divider()
                    .padding(.horizontal)
                    .accessibilityHidden(true)
            }
        }
    }
    
    private func groupAccessibilityLabel(for group: GroupedStopTime) -> String {
        let routeInfo = group.routeShortName
        let destination = group.headsign
        let displayTrack = group.stopTimes.first {
            $0.place.track != nil || $0.place.scheduledTrack != nil
        }?.place.track ?? group.stopTimes.first?.place.scheduledTrack ?? String(localized: "inconnu")
        
        let transport = group.stopTimes.first?.mode.displayName ?? "Bus"
        
        let firstDeparture = group.stopTimes.first?.place.departure ?? group.stopTimes.first?.place.arrival
        let secondDeparture = group.stopTimes.count > 1 ? (group.stopTimes[1].place.departure ?? group.stopTimes[1].place.arrival) : nil
        
        var label = "\(transport) \(routeInfo) en direction de \(destination). \(getTrackType(displayTrack))"
        
        let now = Date()
        
        if let departure = firstDeparture {
            let timeDiff = Int(departure.timeIntervalSince(now))
            
            if timeDiff <= 60 {
                label += ", arrive maintenant"
            } else {
                let minutes = Int(ceil(Double(timeDiff) / 60.0))
                label += ", arrive dans \(minutes) minutes"
            }
        }
        
        if let secondDep = secondDeparture {
            let timeDiff = Int(secondDep.timeIntervalSince(now))
            
            if timeDiff <= 60 {
                label += ", puis maintenant"
            } else {
                let minutes = Int(ceil(Double(timeDiff) / 60.0))
                label += ", puis dans \(minutes) minutes"
            }
        }
        
        return label
    }
}
