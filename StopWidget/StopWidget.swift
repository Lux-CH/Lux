//
//  StopWidget.swift
//  StopWidget
//
//  Created by Constantin Clerc on 29.06.2025.
//

import WidgetKit
import SwiftUI
import LuxCom

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DepartureEntry {
        DepartureEntry(
            date: Date(),
            stopId: "ch_Parent8587057",
            departures: [],
            lastUpdate: Date(),
            error: nil,
            isPreview: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> ()) {
        let numberOfEvents = context.family == .systemLarge ? 9 : 3

        let routeShortNames = ["14", "19", "15", "60", "5", "9", "14", "20", "18"]
        let headsigns = ["Bernex, Vailly", "Onex, cité", "Genève, Nations", "Ferney, mairie", "Thônex, Vallard", "Vernier, Lignon Tours", "Meyrin, Gravière", "Bellevue GE, Valavran", "Meyrin, CERN"]
        var sampleDepartures: [StopTime] = []
        
        var lastDeparture = Date()
        
        for ind in 0..<numberOfEvents {
            let interval = TimeInterval(Int.random(in: 120...480))
            lastDeparture = lastDeparture.addingTimeInterval(interval)
            sampleDepartures.append(StopTime(
                place: Place(
                    name: "Genève, gare Cornavin",
                    stopId: "ch_Parent8587057",
                    lat: 46.2101, lon: 6.1425,
                    level: 0.0,
                    arrival: nil,
                    departure: lastDeparture,
                    scheduledArrival: nil,
                    scheduledDeparture: lastDeparture,
                    scheduledTrack: "1",
                    _track: "1",
                    vertexType: .transit
                ),
                mode: .bus,
                realTime: true,
                headsign: headsigns[ind],
                routeShortName: routeShortNames[ind],
                tripId: "trip_\(ind)",
                agencyId: "881",
                cancelled: false
            ))
        }
        let entry = DepartureEntry(
            date: Date(),
            stopId: getStoredStopId(),
            departures: sampleDepartures,
            lastUpdate: Date(),
            error: nil,
            isPreview: true
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let stopId = getStoredStopId()
        
        let numberOfEvents = context.family == .systemLarge ? 9 : 3
        
        Task {
            do {
                let stopTimes = try await getDeparturesForStop(
                    stopId: stopId,
                    time: Date(),
                    numberOfEvents: numberOfEvents * 3
                )
                
                let prioritizedDepartures = prioritizeDeparturesByLineScore(stopTimes.stopTimes)
                
                let entry = DepartureEntry(
                    date: Date(),
                    stopId: stopId,
                    departures: Array(prioritizedDepartures.prefix(numberOfEvents)),
                    lastUpdate: Date(),
                    error: nil,
                    isPreview: false
                )
                
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
                
            } catch {
                let errorEntry = DepartureEntry(
                    date: Date(),
                    stopId: stopId,
                    departures: [],
                    lastUpdate: Date(),
                    error: error.localizedDescription,
                    isPreview: false
                )
                
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
                let timeline = Timeline(entries: [errorEntry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
    
    private func getStoredStopId() -> String {
        if let sharedDefaults = UserDefaults(suiteName: "group.ch.cclerc.lux.shareddata") {
            return sharedDefaults.string(forKey: "selectedStopId") ?? "ch_Parent8587057"
        }
        return "ch_Parent8587057"
    }
    
    private func prioritizeDeparturesByLineScore(_ departures: [StopTime]) -> [StopTime] {
        let lineScores = loadLineScoresFromSharedStorage()
        
        return departures.sorted { departure1, departure2 in
            let score1 = getLineScore(for: departure1.routeShortName, from: lineScores)
            let score2 = getLineScore(for: departure2.routeShortName, from: lineScores)
            
            if score1 != score2 {
                return score1 > score2
            }
            
            guard let dep1Time = departure1.place.departure,
                  let dep2Time = departure2.place.departure else {
                return false
            }
            
            return dep1Time < dep2Time
        }
    }
    
    private func loadLineScoresFromSharedStorage() -> [LineScore] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.ch.cclerc.lux.shareddata"),
              let data = sharedDefaults.data(forKey: "lineScores") else {
            return []
        }
        
        do {
            let decoder = PropertyListDecoder()
            return try decoder.decode([LineScore].self, from: data)
        } catch {
            print("error loading line scores in widget!!  \(error.localizedDescription)")
            return []
        }
    }
    
    private func getLineScore(for routeShortName: String, from lineScores: [LineScore]) -> Double {
        return lineScores.first { $0.routeShortName == routeShortName }?.totalScore ?? 0.0
    }
}

struct DepartureEntry: TimelineEntry {
    let date: Date
    let stopId: String
    let departures: [StopTime]
    let lastUpdate: Date
    let error: String?
    let isPreview: Bool
}

struct StopWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let placeName = entry.departures.first?.place.name {
                    Text(placeName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                else {
                    Text("Départs")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                Spacer()
                Text(!entry.isPreview ? "Mis à jour à \(formatLastUpdate(entry.lastUpdate))" : "Données fictives")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if entry.error != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Une erreur s'est produite")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entry.departures.isEmpty {
                VStack {
                    Image(systemName: "tram")
                        .foregroundColor(.secondary)
                    Text("Aucun départ ulterieur")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Divider()
                        .padding(.bottom, 5)
                    ForEach(entry.departures) { departure in
                        DepartureRowView(departure: departure)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
    
    private func formatLastUpdate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DepartureRowView: View {
    let departure: StopTime
    
    var body: some View {
        VStack {
            HStack(spacing: 6) {
                LinePill(
                    line: departure.routeShortName,
                    mode: departure.mode,
                    width: 28,
                    height: 18,
                    fontSize: 12
                )
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.primary.opacity(0.3))
                    .font(.system(size: 12))
                Text(departure.headsign ?? "Inconnu")
                    .fontWeight(.regular)
                    .lineLimit(1)
                
                Spacer()
                
                ArrivalMinuteView(incomingStop: departure)
            }
            Divider()
                .padding(.top, -5)
                .padding(.bottom, -5)
        }
    }
}

struct StopWidget: Widget {
    let kind: String = "StopWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                StopWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StopWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Widget des arrêts")
        .description("Afficher les départs d'un arrêt. Configurable dans les paramètres de l'app.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    StopWidget()
} timeline: {
    DepartureEntry(
        date: .now,
        stopId: "ch_Parent8587057",
        departures: [],
        lastUpdate: .now,
        error: nil,
        isPreview: true
    )
}
