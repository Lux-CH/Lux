//
//  DateTimePickerView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct DateTimePickerView: View {
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
            .datePickerStyle(.compact)
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
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                            .background(Color.accentColor.opacity(0.1).cornerRadius(8))
                    )
            }
            .padding(.top, 4)
            
            Divider()
                .padding(.horizontal)
            
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
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 300, height: 150)
//        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}
