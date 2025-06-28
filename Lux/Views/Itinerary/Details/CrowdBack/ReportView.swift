//
//  ReportView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.06.2025.
//

import SwiftUI
import LuxCom

struct ReportView: View {
    let leg: Leg
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedAttribute: ReportAttribute = .crowd
    @State private var selectedLevel: Int = 3
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var showError: Bool = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Signaler une situation")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("Annuler") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 12.5)
                    
                    HStack {
                        LinePill(
                            line: leg.routeShortName ?? "",
                            mode: leg.mode,
                            width: 35,
                            height: 22,
                            fontSize: 11
                        )
                        Text(leg.headsign ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Que souhaitez-vous signaler ?")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach([ReportAttribute.crowd, .clean, .heat, .noise], id: \.self) { attribute in
                            AttributeCard(
                                attribute: attribute,
                                isSelected: selectedAttribute == attribute
                            ) {
                                selectedAttribute = attribute
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Niveau d'intensité")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text(lowLevelText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(highLevelText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { level in
                                Button {
                                    selectedLevel = level
                                } label: {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(level <= selectedLevel ? colorForLevel(level) : Color(.systemGray5))
                                        .frame(height: 6)
                                        .animation(.easeInOut(duration: 0.2), value: selectedLevel)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        HStack {
                            Text("\(selectedLevel)/5")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(colorForLevel(selectedLevel))
                            
                            Spacer()
                            
                            Text(intensityDescription)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(colorForLevel(selectedLevel))
                        }
                    }
                }
                
                Spacer(minLength: 12)
                
                Button {
                    submitReport()
                } label: {
                    HStack(spacing: 6) {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(isSubmitting ? "Envoi..." : "Envoyer")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isSubmitting)
                .opacity(isSubmitting ? 0.7 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .blur(radius: showSuccess || showError ? 3 : 0)
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
            .animation(.easeInOut(duration: 0.3), value: showError)
            
            if showSuccess {
                SuccessOverlay()
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showSuccess)
            }
            
            if showError {
                ErrorOverlay {
                    showError = false
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .opacity
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showError)
            }
        }
    }
    
    private var lowLevelText: String {
        switch selectedAttribute {
        case .crowd: return "Vide"
        case .clean: return "Sale"
        case .heat: return "Froid"
        case .noise: return "Silencieux"
        case .smell: return "Pas d'odeur"
        }
    }
    
    private var highLevelText: String {
        switch selectedAttribute {
        case .crowd: return "Bondé"
        case .clean: return "Propre"
        case .heat: return "Chaud"
        case .noise: return "Bruyant"
        case .smell: return "Forte odeur"
        }
    }
    
    private var intensityDescription: String {
        switch selectedAttribute {
        case .crowd:
            switch selectedLevel {
            case 1: return "Vide"
            case 2: return "Peu occupé"
            case 3: return "Modéré"
            case 4: return "Occupé"
            case 5: return "Bondé"
            default: return ""
            }
        case .clean:
            switch selectedLevel {
            case 1: return "Très sale"
            case 2: return "Sale"
            case 3: return "Correct"
            case 4: return "Propre"
            case 5: return "Très propre"
            default: return ""
            }
        case .heat:
            switch selectedLevel {
            case 1: return "Très froid"
            case 2: return "Froid"
            case 3: return "Tempéré"
            case 4: return "Chaud"
            case 5: return "Très chaud"
            default: return ""
            }
        case .noise:
            switch selectedLevel {
            case 1: return "Silencieux"
            case 2: return "Calme"
            case 3: return "Modéré"
            case 4: return "Bruyant"
            case 5: return "Très bruyant"
            default: return ""
            }
        case .smell:
            switch selectedLevel {
            case 1: return "Pas d'odeur"
            case 2: return "Légère"
            case 3: return "Perceptible"
            case 4: return "Forte"
            case 5: return "Très forte"
            default: return ""
            }
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        let progress = Double(level - 1) / 4.0
        
        switch selectedAttribute {
        case .heat:
            return Color(
                red: progress * 0.9,
                green: 0.1 * (1.0 - progress),
                blue: (1.0 - progress) * 0.9 + 0.1
            )
        case .clean:
            let redComponent = (1.0 - progress) * 0.9
            let greenComponent = progress * 0.8 + 0.1
            return Color(
                red: redComponent,
                green: greenComponent,
                blue: 0.1
            )
        case .crowd, .noise, .smell:
            let redComponent = progress * 0.9
            let greenComponent = (1.0 - progress) * 0.8 + 0.1
            return Color(
                red: redComponent,
                green: greenComponent,
                blue: 0.1
            )
        }
    }
    
    private func submitReport() {
        guard let tripId = leg.tripId,
              let routeShortName = leg.routeShortName,
              let location = locationManager.location else { return }
        
        isSubmitting = true
        
        let report = Report(
            tripId: tripId,
            routeShortName: routeShortName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            attribute: selectedAttribute,
            level: selectedLevel
        )
        
        Task {
            do {
                try await sendLCBReport(report: report)
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    showError = true
                    print("Error sending report: \(error)")
                }
            }
        }
    }
}

struct ErrorOverlay: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "xmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Erreur d'envoi")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Impossible d'envoyer le rapport. Il est possible que vous en ayez récemment envoyé un.\nVeuillez réessayer plus tard.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("OK") {
                onDismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 80, height: 36)
            .background(Color.red)
            .cornerRadius(18)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }
}

struct SuccessOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text("Rapport envoyé !")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Merci pour votre contribution")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }
}

struct AttributeCard: View {
    let attribute: ReportAttribute
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
    
    private var iconName: String {
        switch attribute {
        case .crowd: return "person.3.fill"
        case .smell: return "nose.fill"
        case .clean: return "sparkles"
        case .heat: return "thermometer.medium"
        case .noise: return "speaker.wave.2.fill"
        }
    }
    
    private var displayName: String {
        switch attribute {
        case .crowd: return "Affluence"
        case .smell: return "Odeur"
        case .clean: return "Propreté"
        case .heat: return "Température"
        case .noise: return "Bruit"
        }
    }
}
