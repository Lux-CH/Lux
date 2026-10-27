//
//  WalkingAnnotationView.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2026.
//

import SwiftUI

struct WalkingAnnotationView: View {
    var isCycling = false

    var body: some View {
        if isCycling {
            Image(systemName: "bicycle")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.bikeLeg))
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        } else {
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
        }
    }
}
