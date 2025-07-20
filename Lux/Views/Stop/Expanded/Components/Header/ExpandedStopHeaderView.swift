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
    var onDateSelected: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            
            CustomSegmentedPicker(selection: $viewType)
                .offset(y: animateIn ? 0 : 10)
                .opacity(animateIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: animateIn)
            
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
                RoundedRectangle(cornerRadius: 35)
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

struct CustomSegmentedPicker: View {
    @Binding var selection: String
    private let options = ["Groupé", "Chronologique"]
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option
                    }
                } label: {
                    Text(option)
                        .font(.footnote)
                        .fontWeight(selection == option ? .medium : .regular)
                        .foregroundColor(selection == option ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderless)
                .background(
                    ZStack {
                        if selection == option {
                            RoundedRectangle(cornerRadius: 35)
                                .fill(Color.accentColor.opacity(0.1))
                                .matchedGeometryEffect(id: "selection", in: animation)
                        }
                    }
                )
            }
        }
        .padding(2)
        .overlay(
            RoundedRectangle(cornerRadius: 35)
                .stroke(Color.accentColor.opacity(0.85), lineWidth: 0.1)
        )
        .frame(height: 28)
    }
}
