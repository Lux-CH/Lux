//
//  SearchStopIntent.swift
//  SearchStopIntent
//
//  Created by Constantin Clerc on 03.08.2025.
//

import AppIntents
import LuxCom

struct SearchStopIntent: AppIntent {
    static var title: LocalizedStringResource { "Obtenir les prochains départs" }
    
    @Parameter(title: "Arrêt")
    var stopName: String
    
    func perform() async throws -> some IntentResult & ReturnsValue<[DepartureEntity]> {
        do {
            guard let stop = try await geocode(text: stopName, type: .stop).first else {
                throw $stopName.needsValueError("Aucun arrêt trouvé pour \"\(stopName)\".")
            }
            let stopId = stop.id

            let departures = try await getDeparturesForStop(stopId: stopId, numberOfEvents: 20, radius: 300)
                .filteredToStation(stopId: stopId, name: stop.name, lat: stop.lat, lon: stop.lon, servesRail: stop.servesRail)
                .stopTimes
            
            if departures.isEmpty {
                throw $stopName.needsValueError("Aucun départ trouvé pour l'arrêt \"\(departures.first?.place.name ?? stopName)\".")
            }
            
            let departureEntities = departures.map { DepartureEntity(from: $0) }
            
            return .result(value: departureEntities)
        } catch {
            throw error
        }
    }
}
