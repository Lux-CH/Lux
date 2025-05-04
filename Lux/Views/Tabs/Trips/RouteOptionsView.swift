//
//  RouteOptionsView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.05.2025.
//

import SwiftUI
import LuxCom

struct RouteOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var maxTransfers: Int
    @State private var minTransferTime: Int
    @State private var pedestrianProfile: PedestrianProfile
    @State private var selectedTransportModes: Set<TransportationMode>
    
    private let availableTransportModes: [TransportationMode] = [.bus, .tram, .subway, .rail, .ferry]
    private let onSave: (RouteOptions) -> Void
    private let routeOptions: RouteOptions
    
    init(routeOptions: RouteOptions, onSave: @escaping (RouteOptions) -> Void) {
        self.routeOptions = routeOptions
        self.onSave = onSave
        
        _maxTransfers = State(initialValue: routeOptions.maxTransfers)
        _minTransferTime = State(initialValue: routeOptions.minTransferTime)
        _pedestrianProfile = State(initialValue: routeOptions.pedestrianProfile)
        
        let modes = routeOptions.transitModes ?? []
        _selectedTransportModes = State(initialValue: Set(modes))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        OptionsSection(title: "Transferts") {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Nombre maximum")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    HStack {
                                        ForEach(0...5, id: \.self) { number in
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3)) {
                                                    maxTransfers = number
                                                    HapticFeedback.lightImpact()
                                                }
                                            }) {
                                                Text("\(number)")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .frame(width: 44, height: 44)
                                                    .background(
                                                        Circle()
                                                            .fill(maxTransfers == number ?
                                                                  Color.accentColor :
                                                                  Color(.tertiarySystemFill))
                                                    )
                                                    .foregroundColor(maxTransfers == number ? .white : .primary)
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Temps minimum entre transferts")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    TransferTimeSelector(selectedTime: $minTransferTime)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                        
                        OptionsSection(title: "Accessibilité") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Profil de déplacement")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 10) {
                                    AccessibilityProfileButton(
                                        title: "À pied",
                                        iconName: "figure.walk",
                                        isSelected: pedestrianProfile == .foot,
                                        action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                pedestrianProfile = .foot
                                                HapticFeedback.lightImpact()
                                            }
                                        }
                                    )
                                    
                                    AccessibilityProfileButton(
                                        title: "Fauteuil roulant",
                                        iconName: "figure.roll",
                                        isSelected: pedestrianProfile == .wheelchair,
                                        action: {
                                            withAnimation(.spring(response: 0.3)) {
                                                pedestrianProfile = .wheelchair
                                                HapticFeedback.lightImpact()
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                        
                        OptionsSection(title: "Modes de transport") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(availableTransportModes, id: \.self) { mode in
                                    TransportModeToggle(
                                        mode: mode,
                                        isSelected: selectedTransportModes.contains(mode),
                                        canDeselect: selectedTransportModes.count > 1,
                                        toggle: {
                                            toggleTransportMode(mode)
                                            HapticFeedback.lightImpact()
                                        }
                                    )
                                    
                                    if mode != availableTransportModes.last {
                                        Divider()
                                            .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Options d'itinéraire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button() {
                        saveOptions()
                        HapticFeedback.mediumImpact()
                    } label: {
                        Text("Appliquer")
                            .bold()
                    }
                }
            }
        }
    }
    
    private func toggleTransportMode(_ mode: TransportationMode) {
        withAnimation(.spring(response: 0.3)) {
            if selectedTransportModes.contains(mode) {
                if selectedTransportModes.count > 1 {
                    selectedTransportModes.remove(mode)
                }
            } else {
                selectedTransportModes.insert(mode)
            }
        }
    }
    
    private func saveOptions() {
        let newOptions = RouteOptions(
            from: routeOptions.from,
            to: routeOptions.to,
            via: routeOptions.via,
            viaMinimumStay: routeOptions.viaMinimumStay,
            time: routeOptions.time,
            arriveBy: routeOptions.arriveBy,
            maxTransfers: maxTransfers,
            minTransferTime: minTransferTime,
            pedestrianProfile: pedestrianProfile,
            transitModes: selectedTransportModes.isEmpty ? nil : Array(selectedTransportModes),
            numItineraries: routeOptions.numItineraries,
            pageCursor: routeOptions.pageCursor,
            timetableView: routeOptions.timetableView,
            maxPreTransitTime: routeOptions.maxPreTransitTime,
            maxPostTransitTime: routeOptions.maxPostTransitTime
        )
        
        onSave(newOptions)
        dismiss()
    }
}

// MARK: - Helper Views
struct OptionsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 4)
            
            content
        }
    }
}

struct AccessibilityProfileButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct TransportModeToggle: View {
    let mode: TransportationMode
    let isSelected: Bool
    let canDeselect: Bool
    let toggle: () -> Void
    
    private func getTransportModeInfo() -> (String, String, Color) {
        switch mode {
        case .bus:
            return ("Bus", "bus.fill", .orange)
        case .tram:
            return ("Tram", "tram.fill", .green)
        case .rail:
            return ("Train", "train.side.front.car", .red)
        case .ferry:
            return ("Mouette", "ferry.fill", .cyan)
        default:
            return (mode.rawValue.capitalized, "car.fill", .gray)
        }
    }
    
    var body: some View {
        Button(action: toggle) {
            let (name, icon, color) = getTransportModeInfo()
            
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                
                Text(name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 18, height: 18)
                    }
                }
                .opacity(isSelected || canDeselect ? 1 : 0.5)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isSelected && !canDeselect)
    }
}

struct TransferTimeSelector: View {
    @Binding var selectedTime: Int
    private let timeOptions = [0, 2, 5, 7, 10]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(timeOptions, id: \.self) { seconds in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTime = seconds
                        HapticFeedback.lightImpact()
                    }
                }) {
                    VStack(spacing: 4) {
                        Text("\(seconds)m")
                            .font(.system(size: 15, weight: selectedTime == seconds ? .semibold : .regular))
                            .foregroundColor(selectedTime == seconds ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTime == seconds ? Color.accentColor : Color(.tertiarySystemFill))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}
