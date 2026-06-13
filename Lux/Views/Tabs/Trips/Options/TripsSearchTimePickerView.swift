//
//  TripsSearchTimePickerView.swift
//  Lux
//
//  Created by Constantin Clerc on 26.07.2025.
//

import SwiftUI

struct TripsSearchTimePickerView: View {
    @Binding var selectedDate: Date?
    @Binding var departureType: DepartureType
    @Binding var showDatePicker: Bool
    @ObservedObject var accentColorManager = AccentColorManager.shared
    var onApply: () -> Void
    @State private var localDate: Date
    
    init(selectedDate: Binding<Date?>, departureType: Binding<DepartureType>, showDatePicker: Binding<Bool>, onApply: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self._departureType = departureType
        self._showDatePicker = showDatePicker
        self.onApply = onApply
        self._localDate = State(initialValue: selectedDate.wrappedValue ?? Date())
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Type", selection: $departureType) {
                Text("Partir à").tag(DepartureType.leaveAt)
                Text("Arriver à").tag(DepartureType.arriveBy)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .onAppear {
                if departureType != .leaveAt && departureType != .arriveBy {
                    departureType = .leaveAt
                }
            }
            
            DatePicker(
                "Sélectionner",
                selection: $localDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding(.horizontal)
            .onChange(of: localDate) {
                HapticFeedback.selectionChanged()
            }
            
            if departureType == .leaveAt {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDate = nil
                        showDatePicker = false
                        HapticFeedback.lightImpact()
                        onApply()
                    }
                } label: {
                    Label("Maintenant", systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundColor(accentColorManager.selectedAccentColor)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(accentColorManager.selectedAccentColor.opacity(0.5), lineWidth: 1)
                                .background(accentColorManager.selectedAccentColor.opacity(0.1).cornerRadius(8))
                        )
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.top, 4)
            }
            Divider()
                .padding(.horizontal)
                .overlay(Color(.tertiaryLabel))
            
            HStack {
                Button("Annuler") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showDatePicker = false
                        HapticFeedback.lightImpact()
                    }
                }
                .foregroundColor(Color(.tertiaryLabel))
                .buttonStyle(ScaleButtonStyle())
                
                Spacer()
                
                Button("Appliquer") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDate = localDate
                        showDatePicker = false
                        HapticFeedback.mediumImpact()
                        onApply()
                    }
                }
                .fontWeight(.bold)
                .foregroundColor(accentColorManager.selectedAccentColor)
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 350)
//        .background(
//            colorScheme == .dark ?
//            Color(.secondarySystemBackground) :
//                Color(.systemBackground)
//        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}
