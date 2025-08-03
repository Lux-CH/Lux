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
            guard let stopId = try await geocode(text: stopName, type: .stop).first?.id else {
                throw $stopName.needsValueError("Aucun arrêt trouvé pour \"\(stopName)\".")
            }
            
            let departures = try await getDeparturesForStop(stopId: stopId, numberOfEvents: 5).stopTimes
            
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
