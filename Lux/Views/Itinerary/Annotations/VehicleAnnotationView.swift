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
    
    private let badgeSize: CGFloat = 32
    
    var body: some View {
        ZStack {
            Circle()
                .fill(annotation.color)
                .frame(width: badgeSize, height: badgeSize)
                .shadow(color: annotation.color.opacity(0.7), radius: 4)
                .background {
                    Circle()
                        .stroke(annotation.color.opacity(0.6), lineWidth: 3.5)
                        .frame(width: badgeSize, height: badgeSize)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0 : 0.7)
                        .animation(
                            Animation.easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }
            
            if let routeName = annotation.routeShortName {
                Text(routeName)
                    .font(.custom("NimbusSansBeckerPBla", size: 11))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            if annotation.isLive {
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(annotation.color)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.white))
                    .shadow(color: .black.opacity(0.2), radius: 1.5)
                    .offset(x: 5, y: -5)
                    .accessibilityLabel(Text("Position en direct"))
            }
        }
        .frame(width: 64, height: 64)
        .onAppear {
            isPulsing = true
        }
    }
}
