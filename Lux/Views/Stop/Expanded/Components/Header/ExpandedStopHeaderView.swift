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
    @Environment(\.stopAnimatesIn) private var animatesIn

    private var isIn: Bool { animateIn || !animatesIn }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .rotationEffect(Angle(degrees: isIn ? 0 : -45))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isIn)
                Text("Horaires")
                    .fontWeight(.bold)
                    .offset(x: isIn ? 0 : -20)
                    .opacity(isIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: isIn)
                Spacer()
                datePickerButton
                    .offset(x: isIn ? 0 : 20)
                    .opacity(isIn ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: isIn)
            }
            
            CustomSegmentedPicker(selection: $viewType)
                .offset(y: isIn ? 0 : 10)
                .opacity(isIn ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: isIn)
            
            Divider()
                .padding(.bottom, 0)
                .scaleEffect(x: isIn ? 1 : 0, anchor: .leading)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: isIn)
        }
        .padding(.top, 17.5)
        .padding(.horizontal, 25)
    }
    
    private var formattedDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(selectedDate) {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
            return String(localized:"Aujourd'hui \(formatter.string(from: selectedDate))")
        } else if calendar.isDateInTomorrow(selectedDate) {
            formatter.setLocalizedDateFormatFromTemplate("HH:mm")
            return String(localized:"Demain, \(formatter.string(from: selectedDate))")
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
                Capsule(style: .continuous)
                    .fill(Color.luxAccent.opacity(0.1))
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
    private let options = [String(localized: "Groupé"), String(localized: "Chronologique")]
    @Namespace private var animation
    @Environment(\.colorScheme) var colorScheme
    
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
                        .foregroundColor(selection == option ? Color.luxAccent : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderless)
                .background(
                    ZStack {
                        if selection == option {
                            Capsule(style: .continuous)
                                .fill(Color.luxAccent.opacity(0.12))
                                .matchedGeometryEffect(id: "selection", in: animation)
                        }
                    }
                )
            }
        }
        .padding(2)
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.luxAccent.opacity(0.2), lineWidth: colorScheme == .dark ? 0.5 : 0.75)
        )
        .frame(height: 28)
    }
}

private struct StopAnimatesInKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var stopAnimatesIn: Bool {
        get { self[StopAnimatesInKey.self] }
        set { self[StopAnimatesInKey.self] = newValue }
    }
}
