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
    @Binding var viewType: String
    @ObservedObject var settings = Settings.shared
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
            if settings.allowStopViewModeSelection {
                Picker("", selection: $viewType) {
                    ForEach(["Groupé", "Chronologique"], id: \.self) { option in
                        Text(option)
                            .font(.caption)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(height: 24)
            }
            Divider()
                .padding(.bottom, 0)
                .scaleEffect(x: animateIn ? 1 : 0, anchor: .leading)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: animateIn)
        }
        .padding(.top, 17.5)
        .padding(.horizontal, 25)
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(selectedDate) {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
            return "Aujourd'hui \(formatter.string(from: selectedDate))"
        } else if calendar.isDateInTomorrow(selectedDate) {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
            return "Demain, \(formatter.string(from: selectedDate))"
        } else {
            formatter.setLocalizedDateFormatFromTemplate("dd/MM HH:mm")
            return formatter.string(from: selectedDate)
        }
    }
    
    private var datePickerButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showDatePicker = true
            }
        } label: {
            HStack(spacing: 4) {
                Text(formattedDate)
                    .font(.footnote)
                
                Image(systemName: "calendar")
                    .font(.footnote)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.1))
            )
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
