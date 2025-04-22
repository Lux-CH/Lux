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
            
            HStack {
                Button("Annuler") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDatePicker = false
                    }
                }
                
                Spacer()
                
                Button("Maintenant") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedDate = Date()
                    }
                }
                
                Spacer()
                
                Button("Appliquer") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showDatePicker = false
                    }
                    onApply()
                }
                .fontWeight(.bold)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(width: 300, height: 120)
        .background(Color(.secondarySystemBackground))
    }
}
