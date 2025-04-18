//
//  HomeHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI

struct HomeHeaderView: View {
    @State private var searchText: String = ""
    var body: some View {
        VStack {
            // MARK: Shortcut bar
            HStack {
                ShortcutButton(symbol: "house", coords: (0.0, 0.0))
                ShortcutButton(symbol: "suitcase", coords: (0.0, 0.0))
                Button {
                    print("show settings")
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(Color.primary.opacity(0.6))
                        .font(.system(size: 20))
                        .frame(width: 61, height: 52.5)
                        .background(Color(.secondarySystemFill).opacity(0.5))
                        .cornerRadius(25)
                }
            }
            .padding(.bottom, 5)
            HStack {
                TextField("Aller à...", text: $searchText)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 20)
                    .font(.system(size: 16, weight: .medium))

                Spacer()
                
                Button(action: {
                    print("searching \(searchText)")
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundColor(Color.accentColor)
                }
                .padding(.trailing, 18)
            }
            .frame(width: 350, height: 60)
            .background(Color(.secondarySystemFill).opacity(0.5))
            .cornerRadius(25)
        }
    }
}

#Preview {
    HomeHeaderView()
}
