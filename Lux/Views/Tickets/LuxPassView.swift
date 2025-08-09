//
//  LuxPassView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI

struct LuxPassView: View {
    @ObservedObject private var swissPassManager = LuxPassManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var scanSwissPass: Bool = false
    @State private var showingDeleteAlert: Bool = false
    @Binding var showSwisspassOnHome: Bool
    let isFromHome: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if swissPassManager.isLoading {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Chargement de votre SwissPass...")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if swissPassManager.hasSwissPass {
                    VStack(spacing: 16) {
                        if !isFromHome {
                            HStack {
                                Text("Votre SwissPass")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingDeleteAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 15)
                        }
                        
                        SwissPassView(
                            swissQRCodePass: .constant(swissPassManager.swissQRCodePass),
                            swiss128Pass: .constant(swissPassManager.swiss128Pass)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                        .padding(.horizontal, 8)
                        .padding(.top, -20)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 24) {
                        Image(systemName: "person.text.rectangle")
                            .font(.system(size: 80))
                            .foregroundColor(.red.opacity(0.6))
                        
                        VStack(spacing: 12) {
                            Text("Bienvenue dans LuxPass")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Scannez votre SwissPass pour y accéder en toute sécurité depuis Lux.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        
                        Button("Scanner mon SwissPass") {
                            scanSwissPass = true
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Stockage sécurisé sur votre appareil")
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Accès hors ligne à votre carte")
                                    .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 34))
                            Text("Utilisation non officielle")
                                .font(.title2)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)

                            
                            Text("Cette application n’est ni affiliée ni approuvée par SwissPass ou les SBB CFF.")
                                .font(.body)
                                .multilineTextAlignment(.center)

                            
                            Text("L’affichage du code SwissPass depuis cette application ne garantit pas sa reconnaissance par les contrôleurs.\n\nLux décline toute responsabilité en cas de refus, d’amende ou de tout autre problème. Veuillez toujours avoir votre SwissPass physique ou l'application officielle avec vous.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                                .multilineTextAlignment(.center)

                        }

                        .padding(.horizontal, 14)

                    }
                }
                
                Spacer()
            }
            .navigationTitle("LuxPass")
            .toolbar {
                if isFromHome {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 8) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .symbolRenderingMode(.hierarchical)
                                    .font(.body)
                            }
                            .tint(.secondary)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $scanSwissPass) {
            SwissPassScannerView { qrCode, barcode in
                swissPassManager.saveSwissPass(qrCode: qrCode, barcode: barcode)
            }
        }
        .alert("Supprimer le SwissPass", isPresented: $showingDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                showSwisspassOnHome = false
                swissPassManager.deleteSwissPass()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer votre SwissPass ? Cette action ne peut pas être annulée.")
        }
    }
}
