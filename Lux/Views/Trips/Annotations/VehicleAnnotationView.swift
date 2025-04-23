//
//  VehicleAnnotationView.swift
//  Lux
//
//  Created by Constantin Clerc on 24.04.2025.
//

import SwiftUI

struct VehicleAnnotationView: View {
    let annotation: VehicleAnnotation
    
    var body: some View {
        ZStack {
            Circle()
                .fill(annotation.color)
                .frame(width: 24, height: 24)
                .shadow(radius: 2)
            
            if let routeName = annotation.routeShortName {
                Text(routeName)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            } else {
                Image(systemName: getVehicleIcon())
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
    }
    
    private func getVehicleIcon() -> String {
        switch annotation.mode {
        case .bus: return "bus"
        case .rail, .regionalRail, .regionalFastRail, .highSpeedRail: return "tram"
        case .ferry: return "ferry"
        default: return "bus"
        }
    }
}
