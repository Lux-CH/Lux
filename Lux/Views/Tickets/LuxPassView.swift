//
//  LuxPassView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI

struct LuxPassView: View {
    @StateObject private var swissPassManager = LuxPassManager.shared
    @State private var scanSwissPass: Bool = false
    @State private var showingDeleteAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if swissPassManager.hasSwissPass {
                    VStack(spacing: 16) {
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
                        
                        SwissPassView(
                            swissQRCodePass: .constant(swissPassManager.swissQRCodePass),
                            swiss128Pass: .constant(swissPassManager.swiss128Pass)
                        )
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
                        .foregroundStyle(.accent)
                        .clipShape(Capsule())

                        
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
                    }
                }
                
                Spacer()
            }
            .navigationTitle("LuxPass")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $scanSwissPass) {
            SwissPassScannerView { qrCode, barcode in
                swissPassManager.saveSwissPass(qrCode: qrCode, barcode: barcode)
            }
        }
        .alert("Supprimer le SwissPass", isPresented: $showingDeleteAlert) {
            Button("Supprimer", role: .destructive) {
                swissPassManager.deleteSwissPass()
            }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer votre SwissPass ? Cette action ne peut pas être annulée.")
        }
    }
}

#Preview {
    LuxPassView()
}
