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
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color(red: 0.8, green: 0.1, blue: 0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 2, y: 4)
                
                VStack(spacing: 0) {
                    HStack {
                        VStack {
                            Image(systemName: "person.text.rectangle")
                                .foregroundStyle(.white)

                        }
                        
                        Spacer()
                        
                        Text("swisspass.ch")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    
                    
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 16) {
                        VStack {
                            if !swissQRCodePass.isEmpty {
                                if let qr = barcodeGenerator.generateQrCode(swissQRCodePass) {
                                    qr.resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 80, height: 80)
                                        .background(Color.white)
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center, spacing: 8) {
                            if !swiss128Pass.isEmpty {
                                if let barcode = barcodeGenerator.generateBarcode(swiss128Pass) {
                                    barcode.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 50)
                                        .frame(maxWidth: 175)
                                        .background(Color.white)
                                        .cornerRadius(2)
                                        .clipped()
                                }
                                
                                Text(showIdFormatted(swiss128Pass))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(2)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .frame(maxWidth: 400)
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
