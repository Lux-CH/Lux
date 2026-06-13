//
//  DateTimePickerView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct DateTimePickerView: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    var onApply: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            DatePicker(
                "Sélectionner une date et heure",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding(.horizontal)
            .padding(.top, 12)
            
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedDate = Date()
                }
            } label: {
                Label("Maintenant", systemImage: "clock.arrow.circlepath")
                    .font(.footnote)
                    .foregroundColor(accentColorManager.selectedAccentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(accentColorManager.selectedAccentColor.opacity(0.5), lineWidth: 1)
                            .background(accentColorManager.selectedAccentColor.opacity(0.1).cornerRadius(8))
                    )
            }
            .padding(.top, 4)
            
                Divider()
                    .padding(.horizontal)
                    .overlay(Color(.tertiaryLabel))

            HStack {
                Button("Annuler") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDatePicker = false
                    }
                }
                .foregroundColor(Color(.tertiaryLabel))
                
                Spacer()
                
                Button("Appliquer") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDatePicker = false
                    }
                    onApply()
                }
                .fontWeight(.bold)
                .foregroundColor(accentColorManager.selectedAccentColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 350, height: 332.5)
//        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
