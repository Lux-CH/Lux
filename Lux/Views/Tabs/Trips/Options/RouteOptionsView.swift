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
    @AppStorage("routeOptionsMaxTransfers") private var storedMaxTransfers: Int = 5
    @AppStorage("routeOptionsMinTransferTime") private var storedMinTransferTime: Int = 0
    @AppStorage("routeOptionsPedestrianProfile") private var storedPedestrianProfile: String = PedestrianProfile.foot.rawValue
    @AppStorage("routeOptionsTransportModes") private var storedTransportModes: Data = Data()
    @AppStorage("routeOptionsMaxWalkingTime") private var storedMaxWalkingTime: Int = 900
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    @State private var maxTransfers: Int
    @State private var minTransferTime: Int
    @State private var pedestrianProfile: PedestrianProfile
    @State private var selectedTransportModes: Set<TransportationMode>
    @State private var maxWalkingTime: Int
    @State private var showResetConfirmation = false
    
    private let availableTransportModes: [TransportationMode] = [.bus, .tram, .rail, .ferry]
    private let onSave: (RouteOptions) -> Void
    private let routeOptions: RouteOptions
    
    private let defaultMaxTransfers = 5
    private let defaultMinTransferTime = 0
    private let defaultPedestrianProfile = PedestrianProfile.foot
    private let defaultTransportModes: Set<TransportationMode> = []
    private let defaultMaxWalkingTime = 900
    
    init(routeOptions: RouteOptions, onSave: @escaping (RouteOptions) -> Void) {
        self.routeOptions = routeOptions
        self.onSave = onSave
        
        _maxTransfers = State(initialValue: routeOptions.maxTransfers)
        _minTransferTime = State(initialValue: routeOptions.minTransferTime)
        _pedestrianProfile = State(initialValue: routeOptions.pedestrianProfile)
        
        let modes = routeOptions.transitModes ?? []
        _selectedTransportModes = State(initialValue: Set(modes))
        
        let walkingTime = routeOptions.maxPreTransitTime ?? 900
        _maxWalkingTime = State(initialValue: walkingTime)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerSection
                        .padding(.horizontal)
                    
                    VStack(spacing: 24) {
                        transfersSection
                        walkingTimeSection
                        accessibilitySection
//                        transportModesSection
                        resetSection
                    }
                    .padding(.horizontal)
                    .padding(.top, 22)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemGroupedBackground).opacity(0.3),
                        Color(.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Appliquer") {
                        saveOptions()
                        HapticFeedback.mediumImpact()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(accentColorManager.selectedAccentColor)
                }
            }
            .onAppear {
                loadStoredPreferences()            }
            .confirmationDialog(
                "Rétablir les valeurs par défaut",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Rétablir", role: .destructive) {
                    resetToDefaults()
                    HapticFeedback.mediumImpact()
                }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Cette action rétablira toutes les options aux valeurs par défaut. Cette action ne peut pas être annulée.")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Options d'itinéraire")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    Text("Ajustez votre recherche d'itinéraires")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "slider.horizontal.3")
                        .font(.title)
                        .foregroundStyle(accentColorManager.selectedAccentColor)
                }
            }
        }
    }
    
    private var transfersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OptionHeader(title: String(localized: "Transferts"), icon: "arrow.triangle.2.circlepath")
            
            ModernCard {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nombre maximal")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Définissez le nombre de changements de transport maximal à effectuer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        HStack(spacing: 8) {
                            ForEach(0...5, id: \.self) { number in
                                TransferCountButton(
                                    number: number,
                                    isSelected: maxTransfers == number,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3)) {
                                            maxTransfers = number
                                            storedMaxTransfers = number
                                            HapticFeedback.lightImpact()
                                        }
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                        .opacity(0.5)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Temps minimum entre transferts")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            Text("Définissez le temps minimum d'attente à chaque transfert, pour vous assurer de parvenir à temps à votre connexion")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        
                        TransferTimeSelector(
                            selectedTime: $minTransferTime,
                            onTimeChanged: { newTime in
                                storedMinTransferTime = newTime
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var walkingTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OptionHeader(title: String(localized: "Temps de marche"), icon: "figure.walk")
            
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temps de marche maximal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        
                        Text("Définissez le temps maximal que vous êtes prêt à marcher")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    WalkingTimeSelector(
                        selectedTime: $maxWalkingTime,
                        onTimeChanged: { newTime in
                            storedMaxWalkingTime = newTime
                        }
                    )
                }
            }
        }
    }
    
    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OptionHeader(title: String(localized: "Accessibilité"), icon: "figure.roll")
            
            ModernCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Profil de déplacement")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 12) {
                        AccessibilityProfileButton(
                            title: String(localized: "À pied"),
                            iconName: "figure.walk",
                            isSelected: pedestrianProfile == .foot,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    pedestrianProfile = .foot
                                    storedPedestrianProfile = PedestrianProfile.foot.rawValue
                                    HapticFeedback.lightImpact()
                                }
                            }
                        )
                        
                        AccessibilityProfileButton(
                            title: String(localized:"Fauteuil roulant"),
                            iconName: "figure.roll",
                            isSelected: pedestrianProfile == .wheelchair,
                            action: {
                                withAnimation(.spring(response: 0.3)) {
                                    pedestrianProfile = .wheelchair
                                    storedPedestrianProfile = PedestrianProfile.wheelchair.rawValue
                                    HapticFeedback.lightImpact()
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var transportModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            OptionHeader(title: String(localized: "Modes de transport"), icon: "bus.fill")
            
            VStack(spacing: 12) {
                ModernCard {
                    VStack(spacing: 0) {
                        ForEach(Array(availableTransportModes.enumerated()), id: \.element) { index, mode in
                            TransportModeToggle(
                                mode: mode,
                                isSelected: selectedTransportModes.contains(mode),
                                canDeselect: selectedTransportModes.count > 1,
                                toggle: {
                                    toggleTransportMode(mode)
                                    HapticFeedback.lightImpact()
                                }
                            )
                            
                            if index < availableTransportModes.count - 1 {
                                Divider()
                                    .opacity(0.5)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
                
                ModernCard(style: .normal) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        
                        Text("Cette fonctionnalité n'est pas compatible avec l'itinéraire sélectionné.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var resetSection: some View {
        Button(action: {
            showResetConfirmation = true
            HapticFeedback.lightImpact()
        }) {
            ModernCard(style: .accent, optionalColor: accentColorManager.selectedAccentColor) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.headline.weight(.medium))
                        .foregroundStyle(accentColorManager.selectedAccentColor)
                    
                    Text("Rétablir les valeurs par défaut")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(accentColorManager.selectedAccentColor)
                    
                    Spacer()
                }
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func loadStoredPreferences() {
        maxTransfers = storedMaxTransfers
        minTransferTime = storedMinTransferTime
        maxWalkingTime = storedMaxWalkingTime
        
        if let profile = PedestrianProfile(rawValue: storedPedestrianProfile) {
            pedestrianProfile = profile
        }
        
        if let decodedModes = try? JSONDecoder().decode(Set<TransportationMode>.self, from: storedTransportModes),
           !decodedModes.isEmpty {
            selectedTransportModes = decodedModes
        }
    }
    
    private func saveTransportModesToStorage() {
        if let encodedModes = try? JSONEncoder().encode(selectedTransportModes) {
            storedTransportModes = encodedModes
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
            saveTransportModesToStorage()
        }
    }
    
    private func resetToDefaults() {
        withAnimation(.spring(response: 0.4)) {
            maxTransfers = defaultMaxTransfers
            minTransferTime = defaultMinTransferTime
            pedestrianProfile = defaultPedestrianProfile
            selectedTransportModes = defaultTransportModes
            maxWalkingTime = defaultMaxWalkingTime
            
            storedMaxTransfers = defaultMaxTransfers
            storedMinTransferTime = defaultMinTransferTime
            storedPedestrianProfile = defaultPedestrianProfile.rawValue
            storedMaxWalkingTime = defaultMaxWalkingTime
            saveTransportModesToStorage()
        }
    }
    
    private func saveOptions() {
        let walkingTime = maxWalkingTime == 900 ? nil : maxWalkingTime
        
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
            maxPreTransitTime: walkingTime,
            maxPostTransitTime: walkingTime
        )
        
        onSave(newOptions)
        dismiss()
    }
}

struct OptionHeader: View {
    let title: String
    let icon: String
    @ObservedObject var accentColorManager = AccentColorManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(accentColorManager.selectedAccentColor)
                .font(.caption.weight(.medium))
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

struct TransferCountButton: View {
    let number: Int
    let isSelected: Bool
    let onTap: () -> Void
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        Button(action: onTap) {
            Text("\(number)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? accentColorManager.selectedAccentColor : Color(.tertiarySystemFill))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct AccessibilityProfileButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject var accentColorManager = AccentColorManager.shared
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? accentColorManager.selectedAccentColor : Color(.tertiarySystemFill))
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .white : .primary)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? accentColorManager.selectedAccentColor : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? accentColorManager.selectedAccentColor : Color.clear, lineWidth: 2)
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
            
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 26, height: 26)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 18, height: 18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .opacity(isSelected || canDeselect ? 1 : 0.5)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isSelected && !canDeselect)
    }
}

struct TransferTimeSelector: View {
    @Binding var selectedTime: Int
    let onTimeChanged: (Int) -> Void
    private let timeOptions = [0, 2, 5, 7, 10]
    @ObservedObject var accentColorManager = AccentColorManager.shared

    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(timeOptions, id: \.self) { minutes in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTime = minutes
                        onTimeChanged(minutes)
                        HapticFeedback.lightImpact()
                    }
                }) {
                    VStack(spacing: 4) {
                        Text("\(minutes)m")
                            .font(.system(size: 15, weight: selectedTime == minutes ? .semibold : .regular))
                            .foregroundColor(selectedTime == minutes ? .white : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selectedTime == minutes ? accentColorManager.selectedAccentColor : Color(.tertiarySystemFill))
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

struct WalkingTimeSelector: View {
    @Binding var selectedTime: Int
    let onTimeChanged: (Int) -> Void
    private let walkingTimeOptions = [300, 600, 900, 1200]
    @ObservedObject var accentColorManager = AccentColorManager.shared

    private func formatWalkingTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        return "\(minutes)m"
    }
    
    private func getWalkingDescription(_ seconds: Int) -> String {
        switch seconds {
        case 300:
            return "Courte"
        case 600:
            return "Normale"
        case 900:
            return "Standard"
        case 1200:
            return "Longue"
        default:
            return "Standard"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ForEach(walkingTimeOptions, id: \.self) { seconds in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTime = seconds
                            onTimeChanged(seconds)
                            HapticFeedback.lightImpact()
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(formatWalkingTime(seconds))
                                .font(.system(size: 15, weight: selectedTime == seconds ? .semibold : .regular))
                                .foregroundColor(selectedTime == seconds ? .white : .primary)
                            
                            Text(getWalkingDescription(seconds))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedTime == seconds ? .white.opacity(0.9) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selectedTime == seconds ? accentColorManager.selectedAccentColor : Color(.tertiarySystemFill))
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }
}
