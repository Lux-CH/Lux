//
//  ShortcutEditorView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.05.2025.
//

import SwiftUI
import SymbolPicker
import LuxCom

struct ShortcutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ShortcutEditorViewModel()
    @EnvironmentObject private var shortcutManager: ShortcutManager
    @EnvironmentObject private var locationManager: LocationManager
    @ObservedObject private var accentColorManager = AccentColorManager.shared
    
    var shortcutToEdit: UserShortcut?
    
    @State private var name: String = ""
    @State private var selectedSymbol: String = "house"
    @State private var searchQuery: String = ""
    @State private var selectedLocation: SearchResult?
    @State private var showSymbolPicker = false
    @State private var isSearchActive = false
    @State private var isEditing = false
    
    @State private var hasTimeSchedule = false
    @State private var selectedDays: Set<UserShortcut.TimeSchedule.Weekday> = []
    @State private var selectedTime = Date()
    
    @State private var showContent = false
    @Namespace private var heroNamespace
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal)
                        VStack(spacing: 24) {
                            nameSection
                            symbolSection
                            locationSection
                            timeScheduleSection
                        }
                        .padding(.horizontal)
                        .padding(.top, isEditing ? 0 : 22)
                        .padding(.bottom, 100)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
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
                    Button(isEditing ? "Enregistrer" : "Ajouter") {
                        saveShortcut()
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(canSave ? accentColorManager.selectedAccentColor : .secondary)
                    .disabled(!canSave)
                    .scaleEffect(canSave ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: canSave)
                }
            }
            .onAppear {
                setupForEditing()
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    showContent = true
                }
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPicker(symbol: $selectedSymbol)
                    .navigationTitle("Choisir un symbole")
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isSearchActive) {
                LocationSearchView(
                    searchQuery: $searchQuery,
                    selectedLocation: $selectedLocation,
                    onLocationSelected: { location in
                        selectedLocation = location
                        isSearchActive = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedLocation != nil
    }
    
    private func setupForEditing() {
        if let shortcut = shortcutToEdit {
            isEditing = true
            name = shortcut.name
            selectedSymbol = shortcut.symbol
            
            if let schedule = shortcut.timeSchedule {
                hasTimeSchedule = true
                selectedDays = schedule.daysOfWeek
                
                let calendar = Calendar.current
                let timeComponents = DateComponents(hour: schedule.time.hour, minute: schedule.time.minute)
                selectedTime = calendar.date(from: timeComponents) ?? Date()
            }
            
            viewModel.convertToSearchResult(shortcut: shortcut) { result in
                if let result = result {
                    selectedLocation = result
                }
            }
        }
    }
    
    private func saveShortcut() {
        guard let location = selectedLocation,
              !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let coordinates = UserShortcut.Coordinates(
            latitude: location.lat,
            longitude: location.lon,
            locationName: location.name
        )
        
        var timeSchedule: UserShortcut.TimeSchedule? = nil
        if hasTimeSchedule && !selectedDays.isEmpty {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: selectedTime)
            let minute = calendar.component(.minute, from: selectedTime)
            
            timeSchedule = UserShortcut.TimeSchedule(
                daysOfWeek: selectedDays,
                time: UserShortcut.TimeSchedule.TimeComponents(hour: hour, minute: minute)
            )
        }
        
        let stopId: String? = location.type == .stop ? location.id : nil
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if isEditing, let shortcutId = shortcutToEdit?.id {
            let updatedShortcut = UserShortcut(
                id: shortcutId,
                name: name,
                symbol: selectedSymbol,
                coordinates: coordinates,
                timeSchedule: timeSchedule,
                stopId: stopId
            )
            shortcutManager.updateShortcut(updatedShortcut)
        } else {
            let newShortcut = UserShortcut(
                name: name,
                symbol: selectedSymbol,
                coordinates: coordinates,
                timeSchedule: timeSchedule,
                stopId: stopId
            )
            shortcutManager.addShortcut(newShortcut)
        }
        
        dismiss()
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            if !isEditing {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Créer un raccourci")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        
                        Text("Accédez rapidement à vos destinations préférées")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(accentColorManager.selectedAccentColor)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
            }
        }
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorSectionHeader(title: String(localized: "Nom du raccourci"), icon: "textformat")
            
            TextField("Ex: Maison, Travail, École...", text: $name)
                .textFieldStyle(ModernTextFieldStyle())
                .matchedGeometryEffect(id: "nameField", in: heroNamespace)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
    }
    
    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorSectionHeader(title: String(localized: "Icône"), icon: "heart.circle")
            
            Button {
                showSymbolPicker = true
            } label: {
                ModernCard {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(accentColorManager.selectedAccentColor.opacity(0.1))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: selectedSymbol)
                                .font(.title2.weight(.medium))
                                .foregroundStyle(accentColorManager.selectedAccentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Symbole sélectionné")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            Text(selectedSymbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .font(.caption.weight(.semibold))
                    }
                }
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 40)
        .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorSectionHeader(title: String(localized: "Destination"), icon: "location.circle")
            
            VStack(spacing: 12) {
                Button {
                    isSearchActive = true
                } label: {
                    ModernCard {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(selectedLocation != nil ? Color.red.opacity(0.1) : Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: selectedLocation != nil ? "mappin.circle.fill" : "magnifyingglass")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(selectedLocation != nil ? .red : .secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedLocation?.name ?? "Rechercher une destination")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(selectedLocation != nil ? .primary : .secondary)
                                    .lineLimit(2)
                                
                                if selectedLocation != nil {
                                    Text("Destination sélectionnée")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                
                if selectedLocation == nil {
                    Button {
                        viewModel.useCurrentLocation(locationManager: locationManager) { result in
                            if let result = result {
                                selectedLocation = result
                            }
                        }
                    } label: {
                        ModernCard(style: .accent, optionalColor: accentColorManager.selectedAccentColor) {
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(accentColorManager.selectedAccentColor)
                                    .font(.headline.weight(.medium))
                                
                                Text("Utiliser ma position actuelle")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(accentColorManager.selectedAccentColor)
                                
                                Spacer()
                            }
                        }
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 50)
        .animation(.easeOut(duration: 0.6).delay(0.4), value: showContent)
    }
    
    private var timeScheduleSection: some View {
        VStack(alignment: .center, spacing: 16) {
            HStack {
                EditorSectionHeader(title: String(localized: "Programmation"), icon: "clock.circle")
                
                Spacer()
                
                Toggle("", isOn: $hasTimeSchedule)
                    .toggleStyle(ModernToggleStyle())
                    .onChange(of: hasTimeSchedule) {
                        HapticFeedback.lightImpact()
                    }
            }
            
            if hasTimeSchedule {
                ModernCard {
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            Text("Jours de la semaine")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 6) {
                                ForEach(UserShortcut.TimeSchedule.Weekday.allCases, id: \.self) { day in
                                    DayPickerButton(
                                        day: day,
                                        isSelected: selectedDays.contains(day),
                                        onTap: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                impactFeedback.impactOccurred()
                                                
                                                if selectedDays.contains(day) {
                                                    selectedDays.remove(day)
                                                } else {
                                                    selectedDays.insert(day)
                                                }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        
                        Divider()
                            .opacity(0.5)
                            .frame(height: 0.5)
                            .padding(.horizontal, -8)
                        
                        VStack(spacing: 12) {
                            Text("Heure habituelle")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            
                            VStack(spacing: 6) {
                                DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .clipped()
                                    .padding(.top, -15)
                                
                                Text("Lux vous suggérera ce raccourci à cette heure")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .padding(.top, -4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity).combined(with: .offset(y: -20)),
                    removal: .scale(scale: 0.95).combined(with: .opacity).combined(with: .offset(y: -20))
                ))
            }
            else {
                VStack(alignment: .leading) {
                    Text("En définissant une programmation, Lux vous suggérera le raccourci sur l'écran d'accueil, en fonction du moment de la journée.\nPar exemple, si vous utilisez un raccourci tous les jours à 8h, Lux le mettra en avant autour de cette heure.")
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
                
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 60)
        .animation(.easeOut(duration: 0.6).delay(0.5), value: showContent)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: hasTimeSchedule)
    }
}

struct EditorSectionHeader: View {
    let title: String
    let icon: String
    @ObservedObject private var accentColorManager = AccentColorManager.shared
    
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
