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
    @State private var showTripSearch: Bool = false
    @State private var connections: [String] = []
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "signpost.right")
                        .foregroundStyle(.secondary)
                    Text(stop.name)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                if connections.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(connections, id: \.self) { connection in
                                LinePill(line: connection, mode: .bus)
                            }
                        }
                    }
                }
            }
            .onAppear {
                ConnectionService.shared.getConnections(for: stop.id) { results in
                    connections = results
                }
            }
            Spacer()
            HStack {
                Button {
                    showTripSearch.toggle()
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.circle")
                        .foregroundColor(Color.accentColor)
                        .font(.system(size: 20))
                        .frame(width: 61, height: 52.5)
                        .background(Color(.secondarySystemFill).opacity(0.5))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
        }
        .fullScreenCover(isPresented: $showTripSearch) {
            TripsSearchView(
                initialSearchResult: stop,
                initialTargetField: .to
            )
        }
    }
}

//
//#Preview {
//    StopHeaderView()
//}
