//
//  CalendarManager.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//

import EventKit
import SwiftUI
import LuxCom

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    private let calendarIdentifier = "ch.cclerc.lux.itineraryCal"
    let itinerarySharer: ItinerarySharer
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    init(itinerarySharer: ItinerarySharer) {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        self.itinerarySharer = itinerarySharer
    }
    
    func requestAccess() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, error in
                continuation.resume(returning: granted)
            }
        }
        
        await MainActor.run {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
        
        return granted
    }
    
    private func getLuxCalendar() -> EKCalendar? {
        return eventStore.calendars(for: .event).first { calendar in
            calendar.calendarIdentifier == calendarIdentifier
        }
    }
    
    private func createLuxCalendar() -> EKCalendar? {
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "Itinéraires Lux"
        calendar.cgColor = UIColor.systemOrange.cgColor
        
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            calendar.source = source
        } else if let source = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = source
        } else {
            return nil
        }
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print(error)
            return nil
        }
    }
    
    func saveItineraryToCalendar(_ itinerary: Itinerary) async -> Result<Void, CalendarError> {
        guard authorizationStatus == .fullAccess else {
            return .failure(.notAuthorized)
        }
        
        guard let calendar = getLuxCalendar() ?? createLuxCalendar() else {
            return .failure(.calendarCreationFailed)
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = generateItineraryTitle(itinerary)
        event.startDate = itinerary.startTime
        event.endDate = itinerary.endTime
        event.calendar = calendar
        
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.addAlarm(alarm)
        
        let expiresInHours = Int(ceil(itinerary.endTime.addingTimeInterval(21600).timeIntervalSinceNow / 3600)) // expiration = endTime + 6hr
        
        let uploadResult = await itinerarySharer.uploadItinerary(itinerary, expiresInHours: expiresInHours)
        
        event.notes = generateItineraryNotes(itinerary)
        
        switch uploadResult {
        case .success(let identifier):
            event.url = URL(string: "https://lux.cclerc.ch/share#\(identifier)")
        case .failure:
            print("error while uploading !")
        }
        do {
            try eventStore.save(event, span: .thisEvent)
            return .success(())
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    private func generateItineraryTitle(_ itinerary: Itinerary) -> String {
        guard let firstLeg = itinerary.legs.first,
              let lastLeg = itinerary.legs.last else {
            return "Itinéraire"
        }
        
        var fromName = firstLeg.from.name
        var toName = lastLeg.to.name
        
        if fromName == "START" {
            fromName = firstLeg.to.name
        }
        
        if toName == "END" {
            toName = lastLeg.from.name
        }
        
        return "\(fromName) → \(toName)"
    }
    
    private func generateItineraryNotes(_ itinerary: Itinerary) -> String {
        var notes = "--Itinéraire Lux--\n"
        notes += "Durée : \(formatDuration(itinerary.duration))\n"
        notes += "Nombre de transferts : \(itinerary.transfers)\n"
        
        notes += "\n"
        
        for (index, leg) in itinerary.legs.enumerated() {
            if leg.mode == .walk {
                notes += "  Marchez jusqu'à \(leg.to.name), \(getTrackType(leg.to.track ?? "inconnu"))\n"
            } else {
                if let routeShortName = leg.routeShortName, let headsign = leg.headsign {
                    notes += "  \(index+1). Prenez le (\(routeShortName)) en direction de \(headsign)\n"
                }
                notes += "      Montez à \(leg.from.name)\n"
                notes += "      Descendez à \(leg.to.name)\n"
            }
            notes += "\n"
        }
        
        return notes
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

enum CalendarError: LocalizedError {
    case notAuthorized
    case calendarCreationFailed
    case saveFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Accès au calendrier refusé"
        case .calendarCreationFailed:
            return "Une erreur s'est produite lors de la création du calendrier"
        case .saveFailed(let message):
            return "Impossible de sauvegarder l'événement : \(message)"
        }
    }
}
