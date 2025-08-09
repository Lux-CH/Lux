//
//  LineScoreView.swift
//  Lux
//
//  Created by Constantin Clerc on 25.05.2025.
//

import SwiftUI
import LuxCom

struct LineScoreView: View {
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    @ObservedObject var settings = Settings.shared
    
    @State private var showAddLineSheet = false
    @State private var showLowScoreLines = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    headerCard
                    
                    VStack(spacing: 16) {
                        linesCard
                        quickActionsCard
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddLineSheet) {
                AddLineScoreView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var highScoreLines: [LineScore] {
        lineScoreManager.lineScores.filter { $0.totalScore >= 2.0 }.sorted { $0.totalScore > $1.totalScore }
    }
    
    private var lowScoreLines: [LineScore] {
        lineScoreManager.lineScores.filter { $0.totalScore < 2.0 && $0.totalScore != 0.0 }.sorted { $0.totalScore > $1.totalScore }
    }
    
    private var headerCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            
            Text("Lignes préférées")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Mettez en avant les lignes que vous fréquentez le plus.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)
    }
    
    private var linesCard: some View {
        SettingsCard {
            Section {
                if lineScoreManager.lineScores.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tram")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        
                        Text("Aucune ligne ajoutée")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Ajoutez des lignes pour qu'elles soient mises en avant.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(highScoreLines, id: \.routeShortName) { lineScore in
                        LineScoreRow(lineScore: lineScore)
                    }
                    
                    if !lowScoreLines.isEmpty {
                        VStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showLowScoreLines.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "eye.slash")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    
                                    Text("Ajoutées automatiquement")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(lowScoreLines.count)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(Capsule(style: .continuous))
                                    
                                    Image(systemName: "chevron.right")
                                        .rotationEffect(.degrees(showLowScoreLines ? 90 : 0))
                                        .foregroundColor(.secondary)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color(.quaternarySystemFill))
                            }
                            .buttonStyle(.plain)
                            
                            if showLowScoreLines {
                                VStack(spacing: 0) {
                                    ForEach(lowScoreLines, id: \.routeShortName) { lineScore in
                                        LineScoreRow(lineScore: lineScore)
                                            .opacity(0.7)
                                    }
                                }
                                .frame(maxHeight: showLowScoreLines ? .infinity : 0)
                                .clipped()
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showLowScoreLines)
                                .clipped()
                            }
                        }
                    }
                }
                
                Button {
                    showAddLineSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                        Text("Ajouter une ligne")
                            .foregroundColor(.accentColor)
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
            } header: {
                SectionHeader(
                    icon: "list.bullet",
                    iconColor: .blue,
                    title: String(localized: "Mes lignes"),
                    subtitle: String(localized: "Gérez vos lignes et leurs scores")
                )
            }
        }
    }
    
    private var quickActionsCard: some View {
        SettingsCard {
            Section {
                Button {
                    resetAllScores()
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise",
                        title: String(localized: "Réinitialiser tous les scores"),
                        subtitle: String(localized: "Remet à zéro tous les scores des lignes"),
                        showChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(lineScoreManager.lineScores.isEmpty)
                
            } header: {
                SectionHeader(
                    icon: "gearshape",
                    iconColor: .orange,
                    title: String(localized: "Actions rapides"),
                    subtitle: String(localized: "Gestion globale des scores")
                )
            }
        }
    }
    
    private func resetAllScores() {
        for lineScore in lineScoreManager.lineScores {
            lineScoreManager.deleteScore(for: lineScore.routeShortName)
        }
    }
}

struct LineScoreRow: View {
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    let lineScore: LineScore
    
    var body: some View {
        HStack(spacing: 12) {
            LinePill(
                line: lineScore.routeShortName,
                mode: .bus,
                width: 50,
                height: 30,
                fontSize: 14
            )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ligne \(lineScore.routeShortName)")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("Score: \(String(format: "%.1f", lineScore.totalScore))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        lineScoreManager.addScore(to: lineScore.routeShortName, points: 1.0)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                if lineScore.totalScore > 2.9 {
                    Button {
                        withAnimation {
                            lineScoreManager.addScore(to: lineScore.routeShortName, points: -1.0)
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                    }
                }
                
                Button {
                    withAnimation {
                        lineScoreManager.deleteScore(for: lineScore.routeShortName)
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

struct EditableLinePill: View {
    @ObservedObject var settings = Settings.shared
    @Binding var lineNumber: String
    let mode: TransportationMode
    @FocusState private var isFocused: Bool
    
    private static let squaredModes: Set<TransportationMode> = [
        .regionalRail, .ferry, .rail, .highSpeedRail,
        .longDistance, .metro, .nightRail, .regionalFastRail
    ]
    
    private var isTrainDetected: Bool {
        lineNumber.hasPrefix("RL") || lineNumber.hasPrefix("IR") || lineNumber.hasPrefix("RE") || lineNumber.hasPrefix("IC") || lineNumber == "R"
    }

    private var isSquared: Bool {
        if Self.squaredModes.contains(mode) {
            return true
        }
        else if isTrainDetected {
            return true
        }
        else {
            return false
        }
    }
    
    private var lineColor: Color {
        if isSquared && LineColors.color(for: lineNumber) == nil {
            return Color(hex: "EA0706")
        }
        return LineColors.color(for: lineNumber) ?? .gray
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 4 : 50)
                .fill(settings.highContrastButAccurateLinePill ? lineColor : lineColor.opacity(0.25))
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                .frame(width: 80, height: 50)
            
            TextField("XX", text: $lineNumber)
                .font(.custom("NimbusSansBeckerPBla", size: 18))
                .foregroundColor(settings.highContrastButAccurateLinePill ? LineColors.textColor(for: lineNumber) : (lineColor == .gray ? .primary : lineColor))
                .multilineTextAlignment(.center)
                .textCase(.uppercase)
                .keyboardType(.alphabet)
                .disableAutocorrection(true)
                .focused($isFocused)
                .frame(width: 70)
                .background(Color.clear)
        }
        .onTapGesture {
            isFocused = true
        }
    }
}

struct AddLineScoreView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var lineScoreManager = LineScoreManager.shared

    @State private var lineNumber = ""
    @State private var selectedMode: TransportationMode = .bus
    
    private var isValidLine: Bool {
        !lineNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("Ajouter une ligne")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Entrez le numéro de ligne que vous souhaitez ajouter aux favoris")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(spacing: 12) {
                    Text("Numéro de ligne")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    EditableLinePill(
                        lineNumber: $lineNumber,
                        mode: selectedMode
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        addLine()
                    }
                    .disabled(!isValidLine)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func addLine() {
        let trimmedLine = lineNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        lineScoreManager.addScore(to: trimmedLine, points: 2.0)
        dismiss()
    }
}
