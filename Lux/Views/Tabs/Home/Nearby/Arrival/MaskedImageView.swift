//
//  MaskedImageView.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom

struct MaskedImageView: View {
    @Environment(\.colorScheme) var colorScheme
    let stopIdentifier: String
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(getImageForStop())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 8)
                    .saturation(colorScheme == .light ? 1.5 : 1.0)
                    .contrast(colorScheme == .light ? 1.2 : 1.0)
                    .allowsHitTesting(false)
                    .clipShape(
                        .rect(
                            topLeadingRadius: 38,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 38,
                            style: .continuous
                        )
                    )
                    .mask(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(hex: "D9D9D9").opacity(1.0), location: 0.42),
                                .init(color: Color(hex: "737373").opacity(0.53), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .opacity(colorScheme == .light ? 0.35 : 0.14)
                    )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func getImageForStop() -> String {
        let stopHeaderImages = ["Mountain1", "Jet1", "Rive1", "Rive2", "Vignes1", "Vignes2", "Champel1", "Chambesy1", "Lancy1", "Rive3"]
        let index = abs(stopIdentifier.hashValue) % stopHeaderImages.count
        
        return stopHeaderImages[index]
    }
}

#Preview {
    MaskedImageView(stopIdentifier: "nil")
}
