//
//  SwissPassView.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//

import SwiftUI

struct SwissPassView: View {
    var barcodeGenerator = BarcodeGenerator()
    
    @Binding var swissQRCodePass: String
    @Binding var swiss128Pass: String
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color(red: 0.8, green: 0.1, blue: 0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 12, x: 3, y: 6)
                
                VStack(spacing: 0) {
                    HStack {
                        VStack {
                            Image(systemName: "person.text.rectangle")
                                .foregroundStyle(.white)
                                .font(.system(size: 20))
                        }
                        
                        Spacer()
                        
                        Text("swisspass.ch")
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        if !swissQRCodePass.isEmpty {
                            VStack(spacing: 8) {
                                if let qr = barcodeGenerator.generateQrCode(swissQRCodePass) {
                                    qr.resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .allowedDynamicRange(.high)
                                        .frame(width: 120, height: 120)
                                        .background(Color.white)
                                        .cornerRadius(6)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                                }
                            }
                        }
                        
                        if !swiss128Pass.isEmpty {
                            VStack(spacing: 8) {
                                if let barcode = barcodeGenerator.generateBarcode(swiss128Pass) {
                                    barcode.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .allowedDynamicRange(.high)
                                        .frame(height: 70)
                                        .frame(maxWidth: 250)
                                        .background(Color.white)
                                        .cornerRadius(4)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)
                                        .clipped()
                                }
                                
                                Text(showIdFormatted(swiss128Pass))
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .frame(maxWidth: 500)
        .padding()
    }
    
    private func showIdFormatted(_ input: String) -> String {
        var result = ""
        for (index, char) in input.enumerated() {
            if index != 0 && index % 3 == 0 {
                result.append("-")
            }
            result.append(char)
        }
        return result
    }
}
