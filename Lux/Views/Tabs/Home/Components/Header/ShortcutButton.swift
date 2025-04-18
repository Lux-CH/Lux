//
//  ShortcutButton.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI

struct ShortcutButton: View {
    var symbol: String
    var coords: (Double, Double)
    
    var body: some View {
        Button {
            print("go to \(coords)")
        } label: {
            Image(systemName: symbol)
                .foregroundColor(Color.accentColor)
                .font(.system(size: 20))
                .frame(width: 134, height: 52.5)
                .background(Color(.secondarySystemFill).opacity(0.5))
                .cornerRadius(25)
        }
    }
}

#Preview {
    HomeHeaderView()
}
