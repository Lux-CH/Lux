//
//  StopHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI
import LuxCom

struct StopHeaderView: View {
    @State var stop: SearchResult
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "signpost.right")
                    Text(stop.name)
                        .fontWeight(.bold)
                }
                VStack {
                    LinePill(line: "80", mode: .bus)
                }
            }
            Spacer()
            HStack {
                Button {
                    print("go!")
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.circle")
                        .foregroundColor(Color.accentColor)
                        .font(.system(size: 20))
                        .frame(width: 61, height: 52.5)
                        .background(Color(.secondarySystemFill).opacity(0.5))
                        .clipShape(Circle())
                }
                Button {
                    print("search!")
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.accentColor)
                        .font(.system(size: 20))
                        .frame(width: 61, height: 52.5)
                        .background(Color(.secondarySystemFill).opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
    }
}
//
//#Preview {
//    StopHeaderView()
//}
