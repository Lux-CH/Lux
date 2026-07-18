//
//  LegHeaderView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.07.2025.
//

import SwiftUI
import LuxCom

struct LegHeaderView: View {
    let leg: Leg
    let legColor: Color
    let isSingle: Bool
    let nextStop: Place?
    @State private var showTripIdView: Bool = false
    @State private var lineInfo: InfoResponse?
    @State private var showReportCard: Bool = false
    @EnvironmentObject var locationManager: LocationManager
    @ObservedObject var settings = Settings.shared
    
    var body: some View {
        Group {
            if !isSingle, let tripId = leg.tripId {
                Button {
                    showTripIdView = true
                } label: {
                    contentView
                }
                .buttonStyle(PlainButtonStyle())
                .fullScreenCover(isPresented: $showTripIdView) {
                    ItineraryView(tripId: tripId, fromNearby: false)
                }
            } else {
                contentView
            }
        }
        .onAppear {
            if settings.crowdbackAllowed {
                loadLineInfo()
            }
        }
    }
    
    private var contentView: some View {
        HStack(alignment: .top, spacing: 10) {
            LinePill(line: leg.routeShortName ?? "",
                     mode: leg.mode,
                     agency: leg.agencyId,
                     width: 64,
                     height: 40,
                     fontSize: 19)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(legColor.opacity(0.7))
                    Text(leg.headsign ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if settings.crowdbackAllowed {
                        Button {
                            showReportCard = true
                        } label: {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 16))
                        }
                        .foregroundStyle(.gray)
                        .sheet(isPresented: $showReportCard, onDismiss: {loadLineInfo()}) {
                            ReportView(leg: leg)
                                .presentationDetents([.fraction(0.6)])
                                .presentationCornerRadius(38)
                        }
                    }
                }
                HStack(spacing: 4) {
                    if let nextStop = nextStop {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Prochain: \(nextStop.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
//                            .lineLimit(1)
//                            .frame(maxWidth: 250, alignment: .leading)
//                            .truncationMode(.head)
                    }
                    else {
                        let systemName: String = {
                            switch leg.mode {
                            case .tram: return "tram"
                            case .ferry: return "ferry"
                            case .bus: return "bus"
                            case .rail, .highSpeedRail, .regionalFastRail, .regionalRail: return "tram.tunnel.fill"
                            default: return "bus"
                            }
                        }()
                        Image(systemName: systemName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("Montez à \(formatTime(leg.startTime))")
                            .bold()
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                if settings.crowdbackAllowed {
                    LineInfoView(info: lineInfo)
                }
            }
        }
    }
    
    private func loadLineInfo() {
        guard let tripId = leg.tripId,
              let routeShortName = leg.routeShortName,
              let location = locationManager.location else { return }
                
        Task {
            do {
                let info = try await getLCBInfo(
                    tripId: tripId,
                    routeShortName: routeShortName,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                
                await MainActor.run {
                    self.lineInfo = info
                }
            } catch {
                await MainActor.run {
                    self.lineInfo = nil
                }
                if case APIError.requestFailed(404, _) = error {
                    return
                }
                else {
                    print("error loading line info : \(error)")
                }
            }
        }
    }
}
