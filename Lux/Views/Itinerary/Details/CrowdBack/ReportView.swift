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
                            Text("Faible")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Élevé")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { level in
                                Button {
                                    selectedLevel = level
                                } label: {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(level <= selectedLevel ? Color.accentColor : Color(.systemGray5))
                                        .frame(height: 6)
                                        .animation(.easeInOut(duration: 0.2), value: selectedLevel)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Text("\(selectedLevel)/5")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .center)
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
            .blur(radius: showSuccess ? 3 : 0)
            .animation(.easeInOut(duration: 0.3), value: showSuccess)
            
            // Success Overlay
            if showSuccess {
                SuccessOverlay()
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showSuccess)
            }
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
                    print("Error sending report: \(error)")
                }
            }
        }
    }
}

struct SuccessOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            // Success Icon
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
