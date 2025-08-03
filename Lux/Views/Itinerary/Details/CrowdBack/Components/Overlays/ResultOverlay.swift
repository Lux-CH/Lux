//
//  ResultOverlay.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import SwiftUI

struct ErrorOverlay: View {
    let failedReports: Int
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text(failedReports == 0 ? String(localized: "Erreur de rapport") : String(localized: "Rapport partiel"))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(failedReports == 0
                     ? String(localized: "Impossible d'envoyer les rapports. Veuillez réessayer plus tard.")
                     : String(localized: "\(failedReports) rapport(s) n'ont pas pu être envoyés. Les autres ont été transmis avec succès."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                onDismiss()
            } label: {
                Text(String(localized: "OK"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: 80, height: 36)
                    .background(Color.red)
                    .cornerRadius(18)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }
}

struct SuccessOverlay: View {
    let reportCount: Int
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 6) {
                Text(String(localized: "Rapports envoyés !"))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(String(localized: "\(reportCount) rapport(s) transmis avec succès.\nMerci pour votre contribution !"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 40)
    }
}

