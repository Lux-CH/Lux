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
    @Environment(\.colorScheme) private var colorScheme
    
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
    
    // MARK: - Computed Properties for Filtering
    private var highScoreLines: [LineScore] {
        lineScoreManager.lineScores.filter { $0.totalScore >= 2.0 }.sorted { $0.totalScore > $1.totalScore }
    }
    
    private var lowScoreLines: [LineScore] {
        lineScoreManager.lineScores.filter { $0.totalScore < 2.0 }.sorted { $0.totalScore > $1.totalScore }
    }
    
    // MARK: - Header Card
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal)
    }
    
    // MARK: - Lines Card
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
                                withAnimation(.easeInOut(duration: 0.3)) {
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
                                        .clipShape(Capsule())
                                    
                                    Image(systemName: showLowScoreLines ? "chevron.up" : "chevron.down")
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
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .top)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
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
                    title: "Mes lignes",
                    subtitle: "Gérez vos lignes et leurs scores"
                )
            }
        }
    }
    
    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        SettingsCard {
            Section {
                Button {
                    resetAllScores()
                } label: {
                    SettingsRow(
                        icon: "arrow.clockwise",
                        title: "Réinitialiser tous les scores",
                        subtitle: "Remet à zéro tous les scores des lignes",
                        showChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(lineScoreManager.lineScores.isEmpty)
                
            } header: {
                SectionHeader(
                    icon: "gear",
                    iconColor: .orange,
                    title: "Actions rapides",
                    subtitle: "Gestion globale des scores"
                )
            }
        }
    }
    
    private func resetAllScores() {
        for lineScore in lineScoreManager.lineScores {
            lineScoreManager.resetScore(for: lineScore.routeShortName)
        }
    }
}

// MARK: - Supporting Views

struct LineScoreRow: View {
    @ObservedObject var lineScoreManager = LineScoreManager.shared
    let lineScore: LineScore
    @State private var showingDeleteAlert = false
    
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
                    lineScoreManager.addScore(to: lineScore.routeShortName, points: 1.0)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                Button {
                    lineScoreManager.resetScore(for: lineScore.routeShortName)
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
                
                Button {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .alert("Supprimer la ligne", isPresented: $showingDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                lineScoreManager.deleteScore(for: lineScore.routeShortName)
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer la ligne \(lineScore.routeShortName) de vos favoris ?")
        }
    }
}

// MARK: - New Editable Line Pill Component
struct EditableLinePill: View {
    @ObservedObject var settings = Settings.shared
    @Binding var lineNumber: String
    let mode: TransportationMode
    @FocusState private var isFocused: Bool
    
    private var isSquared: Bool {
        mode == .regionalRail || mode == .ferry
    }
    
    private var formattedLine: String {
        lineNumber.hasPrefix("RL") ? String(lineNumber.dropFirst(1)) : lineNumber
    }
    
    private var lineColor: Color {
        if mode == .regionalRail && LineColors.color(for: lineNumber) == nil {
            return Color(hex: "EA0706")
        }
        return LineColors.color(for: lineNumber) ?? .gray
    }
    
    private var displayText: String {
        formattedLine.isEmpty ? "XX" : formattedLine
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSquared ? 4 : 50)
                .fill(settings.highContrastButAccurateLinePill ? lineColor : lineColor.opacity(0.25))
                .frame(width: 80, height: 50)
            
            TextField("XX", text: $lineNumber)
                .font(.custom("NimbusSansBeckerPBla", size: 18))
                .foregroundColor(settings.highContrastButAccurateLinePill ? LineColors.textColor(for: lineNumber) : (lineColor == .gray ? .primary : lineColor))
                .multilineTextAlignment(.center)
                .textCase(.uppercase)
                .autocorrectionDisabled()
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
                
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.accentColor)
                    
                    Text("Ajouter une ligne")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tapez le numéro de ligne pour l'ajouter aux favoris")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Large Editable Pill
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
