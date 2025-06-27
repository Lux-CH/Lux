//
//  ItineraryDetailSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 24.04.2025.
//
//  https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/

import SwiftUI
import LuxCom

struct ItineraryDetailSheet: View {
    let viewModel: ItineraryViewModel
    
    var body: some View {
        if let itinerary = viewModel.itinerary {
            if itinerary.legs.count == 1 && itinerary.legs.first?.mode != .walk {
                IndividualItineraryDetailView(itinerary: itinerary)
            } else {
                MultipleItineraryDetailView(itinerary: itinerary, viewModel: viewModel)
            }
        } else {
            ContentUnavailableView {
                Label("Itinéraire indisponible", systemImage: "map.fill")
            } description: {
                Text("Les informations de l'itinéraire ne sont pas disponibles pour le moment.")
            }
        }
    }
}

struct LegHeaderView: View {
    let leg: Leg
    let legColor: Color
    let isSingle: Bool
    let nextStop: Place?
    @State private var showTripIdView: Bool = false
    @State private var lineInfo: InfoResponse?
    @State private var isLoadingInfo: Bool = false
    @EnvironmentObject var locationManager: LocationManager
    
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
            loadLineInfo()
        }
        .onChange(of: leg.tripId) {
            loadLineInfo()
        }
    }
    
    private var contentView: some View {
        HStack(spacing: 15) {
            LinePill(line: leg.routeShortName ?? "",
                     mode: leg.mode,
                     width: 64,
                     height: 40,
                     fontSize: 19)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Image(systemName: "arrow.right")
                        .foregroundStyle(legColor.opacity(0.7))
                    Text(leg.headsign ?? "")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
                
                if let nextStop = nextStop {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("Prochain: \(nextStop.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                LineInfoView(info: lineInfo, isLoading: isLoadingInfo)
            }
            Spacer()
        }
    }
    
    private func loadLineInfo() {
        guard let tripId = leg.tripId,
              let routeShortName = leg.routeShortName,
              let location = locationManager.location else { return }
        
        isLoadingInfo = true
        
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
                    self.isLoadingInfo = false
                }
            } catch {
                await MainActor.run {
                    self.lineInfo = nil
                    self.isLoadingInfo = false
                }
                print("error loading line info : \(error)")
            }
        }
    }
}

struct StopStatus {
    let isCurrentStop: Bool
    let timeUntil: String
}

func calculateStopStatus(stop: Place, currentDate: Date) -> StopStatus {
    let preArrivalWindow: TimeInterval = 60
    let postArrivalWindow: TimeInterval = 60
    let preDepartureWindow: TimeInterval = 60
    let postDepartureWindow: TimeInterval = 60
    
    let now = currentDate
    
    var isCurrentStop = false
    
    if let arrival = stop.arrival, let departure = stop.departure {
        if now >= arrival && now <= departure {
            isCurrentStop = true
        } else if now >= arrival.addingTimeInterval(-preArrivalWindow) &&
                    now <= departure.addingTimeInterval(postDepartureWindow) {
            isCurrentStop = true
        }
    }
    else if let departure = stop.departure {
        isCurrentStop = now >= departure.addingTimeInterval(-preDepartureWindow) &&
        now <= departure.addingTimeInterval(postDepartureWindow)
    }
    else if let arrival = stop.arrival {
        isCurrentStop = now >= arrival.addingTimeInterval(-preArrivalWindow) &&
        now <= arrival.addingTimeInterval(postArrivalWindow)
    }
    
    return StopStatus(isCurrentStop: isCurrentStop, timeUntil: calculateTimeUntilReachingStop(for: stop, now: now, isCurrentStop: isCurrentStop))
}

func calculateTimeUntilReachingStop(for stop: Place, now: Date, isCurrentStop: Bool) -> String {
    guard let relevantTime = stop.departure ?? stop.arrival else {
        return ""
    }
    
    let secondsDifference = Int(relevantTime.timeIntervalSince(now))
    
    if secondsDifference <= 0 {
        return isCurrentStop ? "Maintenant" : ""
    }
    
    if secondsDifference < 60 {
        return "<1 min"
    }
    
    let minutes = Int(ceil(Double(secondsDifference) / 60.0))
    
    if minutes < 100 {
        return "\(minutes) min"
    }
    
    let hours = minutes / 60
    let remainingMinutes = minutes % 60
    
    if remainingMinutes == 0 {
        return "\(hours) h"
    } else {
        return "\(hours) h \(remainingMinutes) min"
    }
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
