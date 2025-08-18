//
//  LineStylePicker.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI

struct LineStylePicker<SelectionValue: Hashable>: View {
    @ObservedObject var accentColorManager = AccentColorManager.shared
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]
    let linesToPick = ["18", "80", "10", "14", "29", "17", "2", "3", "RL4", "60"]
    @Namespace private var animation
    
    @State private var randomLine: String = "18"
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(accentColorManager.selectedAccentColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: 4) {
                ForEach(options, id: \.value) { option in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selection = option.value
                        }
                    } label: {
                        VStack(spacing: 8) {
                            SamplePill(
                                line: randomLine,
                                isEasyOnTheEyes: getIsEasyOnTheEyes(for: option.value),
                                isRealistic: getIsRealistic(for: option.value)
                            )
                            .scaleEffect(isSelected(option.value) ? 1.05 : 1.0)
                            
                            Text(option.label)
                                .font(.caption)
                                .fontWeight(isSelected(option.value) ? .semibold : .regular)
                                .foregroundColor(isSelected(option.value) ? accentColorManager.selectedAccentColor : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderless)
                    .background(
                        ZStack {
                            if isSelected(option.value) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(accentColorManager.selectedAccentColor.opacity(0.15))
                                    .matchedGeometryEffect(id: "lineStyleSelection", in: animation)
                            }
                        }
                    )
                }
            }
            .padding(4)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .onAppear {
            randomLine = linesToPick.randomElement() ?? "18"
            
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                withAnimation(.linear(duration: 0.3)) {
                    let availableLines = linesToPick.filter { $0 != randomLine }
                    randomLine = availableLines.randomElement() ?? linesToPick.first ?? "18"
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func isSelected(_ value: SelectionValue) -> Bool {
        selection == value
    }
    
    private func getIsEasyOnTheEyes(for value: SelectionValue) -> Bool {
        if let intValue = value as? Int {
            return intValue == 2
        }
        return false
    }
    
    private func getIsRealistic(for value: SelectionValue) -> Bool {
        if let intValue = value as? Int {
            return intValue == 1
        }
        return false
    }
}
