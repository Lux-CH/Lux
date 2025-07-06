//
//  StopTypeLabel.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2025.
//

import SwiftUI

struct StopTypeLabel: View {
    let isDepartureStop: Bool
    let isArrivalStop: Bool
    
    var body: some View {
        Group {
            if isDepartureStop {
                Text("Départ")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            } else if isArrivalStop {
                Text("Arrivée")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.15))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
        }
    }
}
