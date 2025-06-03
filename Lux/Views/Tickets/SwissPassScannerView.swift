//
//  SwissPassScannerView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI
import CodeScanner

struct SwissPassScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onScanSuccess: (String, String) -> Void
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    private let swissPassQRPrefix = "HTTP://1SP.CH?S="
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    
                    Text("Scannez votre SwissPass")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Positionnez l'arrière de votre carte SwissPass dans le cadre pour l'ajouter à LuxPass")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 100)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: 350, height: 225)
                    
                    CodeScannerView(
                        codeTypes: [.qr, .code128],
                        scanMode: .continuous,
                        completion: handleScanResult
                    )
                    .frame(width: 350, height: 225)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    if isProcessing {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 350, height: 225)

                        VStack {
                            ProgressView()
                                .tint(.red)
                            Text("Traitement...")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Erreur de scan", isPresented: $showingError) {
            Button("Réessayer", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleScanResult(_ result: Result<ScanResult, ScanError>) {
        guard !isProcessing else { return }
        
        switch result {
        case .success(let scanResult):
            isProcessing = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let (qrCode, barcode) = processSwissPassCode(scanResult.string) {
                    onScanSuccess(qrCode, barcode)
                    dismiss()
                } else {
                    isProcessing = false
                    showError("Code SwissPass non reconnu. Veuillez réessayer avec un SwissPass valide.")
                }
            }
            
        case .failure(let error):
            showError("Erreur lors du scan : \(error.localizedDescription)")
        }
    }
    
    private func processSwissPassCode(_ scannedString: String) -> (String, String)? {
        if scannedString.uppercased().hasPrefix(swissPassQRPrefix) {
            let code = String(scannedString.dropFirst(swissPassQRPrefix.count))
            if isValidSwissPassCode(code) {
                return (scannedString.uppercased(), code)
            }
        }
        else if isValidSwissPassCode(scannedString) {
            return (swissPassQRPrefix + scannedString, scannedString)
        }
        
        return nil
    }
    
    private func isValidSwissPassCode(_ code: String) -> Bool {
        guard code.count == 12,
              code.hasPrefix("S"),
              let _ = Int(String(code.dropFirst())) else {
            return false
        }
        return true
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
