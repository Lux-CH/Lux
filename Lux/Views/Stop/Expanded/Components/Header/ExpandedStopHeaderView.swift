//
//  ExpandedStopHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 22.04.2025.
//

import SwiftUI

struct ExpandedStopHeaderView: View {
    @Binding var showDatePicker: Bool
    @Binding var animateIn: Bool
    @Binding var selectedDate: Date
    var onDateSelected: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "clock")
                    .rotationEffect(Angle(degrees: animateIn ? 0 : -45))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animateIn)
                Text("Horaires")
                    .fontWeight(.bold)
                    .offset(x: animateIn ? 0 : -20)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: animateIn)
                Spacer()
                datePickerButton
                    .offset(x: animateIn ? 0 : 20)
                    .opacity(animateIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: animateIn)
            }
            Divider()
                .padding(.bottom, 0)
                .scaleEffect(x: animateIn ? 1 : 0, anchor: .leading)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateIn)
        }
        .padding(.top, 17.5)
        .padding(.horizontal, 25)
    }
    
    private var datePickerButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showDatePicker = true
            }
        } label: {
            Label("Changer la date", systemImage: "calendar")
                .font(.footnote)
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $showDatePicker, arrowEdge: .top) {
            DateTimePickerView(
                selectedDate: $selectedDate,
                showDatePicker: $showDatePicker,
                onApply: onDateSelected
            )
            .presentationCompactAdaptation(.popover)
        }
    }
}
