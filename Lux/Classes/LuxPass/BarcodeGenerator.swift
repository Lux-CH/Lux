//
//  BarcodeGenerator.swift
//  Lux
//
//  Created by Constantin Clerc on 02.06.2025.
//
//  https://www.appcoda.com/swiftui-barcode-generator/

import CoreImage.CIFilterBuiltins
import SwiftUI

struct BarcodeGenerator {
    let context = CIContext()

    func generateBarcode(_ text: String) -> Image? {
        let generator = CIFilter.code128BarcodeGenerator()
        generator.message = Data(text.utf8)
        
        if let outputImage = generator.outputImage {
            let scaleTransform = CGAffineTransform(scaleX: 3, y: 3)
            let scaledImage = outputImage.transformed(by: scaleTransform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }
    
    func generateQrCode(_ text: String) -> Image? {
        let generator = CIFilter.qrCodeGenerator()
        generator.message = Data(text.utf8)
        
        if let outputImage = generator.outputImage {
            let scaleTransform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: scaleTransform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                let uiImage = UIImage(cgImage: cgImage)
                return Image(uiImage: uiImage)
            }
        }
        return nil
    }
}
