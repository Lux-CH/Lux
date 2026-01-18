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
    @State private var showAlert: Bool = false
    @State private var name = ""
    @ObservedObject var settings = Settings.shared
    
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
                    .safeAreaInset(edge: .trailing) {
                        Spacer().frame(height: 15)
                    }
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black, Color.clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 30)
                        }
                    )
                }
            }
            .onAppear {
                ConnectionService.shared.getConnections(for: stop.id) { results in
                    connections = results
                }
            }
            Spacer()
            HStack {
                if settings.showDebug {
                    Button {
                        showAlert = true
                    } label: {
                        Image(systemName: "link")
                            .foregroundColor(Color.accentColor)
                            .font(.system(size: 13.3))
                            .frame(width: 40.5, height: 35)
                            .background(Color(.secondarySystemFill).opacity(0.5))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            )
                    }
                }
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
        .navigationDestination(isPresented: $showTripSearch) {
            TripsSearchView(
                initialSearchResult: {
                    if settings.dataSource == .cita {
                        return SearchResult(
                            type: .place,
                            tokens: stop.tokens,
                            name: stop.name,
                            id: "",
                            lat: stop.lat,
                            lon: stop.lon,
                            areas: stop.areas,
                            score: stop.score
                        )
                    } else {
                        return stop
                    }
                }(),
                initialTargetField: .to
            )
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
        }
        .alert("Entrez le nom du lieu", isPresented: $showAlert) {
            TextField("", text: $name)
            Button("Copier le lien dans la presse-papier", action: {
                if let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) {
                    UIPasteboard.general.string = "https://lux.cclerc.ch/place.html#\(encodedName)-\(stop.id.replacingOccurrences(of: "ch_Parent", with: "").replacingOccurrences(of: "ch_", with: ""))"
                }
            })
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Afin de partager un lieu via Lux, vous devez entrer son nom. Le lieu sera partagé pour l'arrêt ouvert.")
        }
    }
}

//
//#Preview {
//    StopHeaderView()
//}
