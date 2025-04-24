//
//  VehicleAnnotationView.swift
//  Lux
//
//  Created by Constantin Clerc on 24.04.2025.
//

import SwiftUI

struct VehicleAnnotationView: View {
    let annotation: VehicleAnnotation
    @State private var isPulsing = false
    @State private var isSecondPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(annotation.color.opacity(0.6), lineWidth: 3.5)
                .frame(width: 48, height: 48)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.7)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: false),
                    value: isPulsing
                )
            
            Circle()
                .stroke(annotation.color.opacity(0.4), lineWidth: 2.5)
                .frame(width: 38, height: 38)
                .scaleEffect(isSecondPulsing ? 1.4 : 1.0)
                .opacity(isSecondPulsing ? 0 : 0.5)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .delay(0.7)
                        .repeatForever(autoreverses: false),
                    value: isSecondPulsing
                )
            
            Circle()
                .fill(annotation.color)
                .frame(width: 32, height: 32)
                .shadow(color: annotation.color.opacity(0.7), radius: 4)
            
            if let routeName = annotation.routeShortName {
                Text(routeName)
                    .font(.custom("NimbusSansBeckerPBla", size: 11))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            isPulsing = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSecondPulsing = true
            }
        }
    }
}
