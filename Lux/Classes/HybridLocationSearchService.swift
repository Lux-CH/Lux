//
//  HybridLocationSearchService.swift
//  Lux
//
//  Created by Constantin Clerc on 27.04.2026.
//

import Foundation
import CoreLocation
import MapKit
import LuxCom

struct HybridLocationSearchService {
    private let maxCompletionRequests = 3
    private let maxReturnedPlaces = 10
    
    func search(query: String, userLocation: CLLocationCoordinate2D?) async -> [SearchResult] {
        async let stopSearchResults = searchStops(query: query, userLocation: userLocation)
        async let placeSearchOutcome = searchPlaces(query: query, userLocation: userLocation)
        
        let stopResults = await stopSearchResults
        let placeOutcome = await placeSearchOutcome
        
        var mergedResults = stopResults + placeOutcome.results
        
        // Fallback to full Lux geocoding only when MapKit is rate-limited.
        if placeOutcome.wasRateLimited {
            let luxFallback = await searchLuxFallbackAll(query: query, userLocation: userLocation)
            mergedResults.append(contentsOf: luxFallback)
        }
        
        let deduplicatedResults = deduplicated(results: mergedResults)
        return sortedByClosestDistance(deduplicatedResults, userLocation: userLocation)
    }
    
    private func searchStops(query: String, userLocation: CLLocationCoordinate2D?) async -> [SearchResult] {
        do {
            if let userLocation {
                return try await geocode(
                    text: query,
                    type: .stop,
                    place: (userLocation.latitude, userLocation.longitude),
                    placeBias: 2
                )
            }
            return try await geocode(text: query, type: .stop)
        } catch {
            print("stop geocode error: \(error.localizedDescription)")
            return []
        }
    }
    
    private func searchLuxFallbackAll(query: String, userLocation: CLLocationCoordinate2D?) async -> [SearchResult] {
        do {
            if let userLocation {
                return try await geocode(
                    text: query,
                    place: (userLocation.latitude, userLocation.longitude),
                    placeBias: 2
                )
            }
            
            return try await geocode(text: query)
        } catch {
            print("lux fallback geocode error: \(error.localizedDescription)")
            return []
        }
    }
    
    private func searchPlaces(query: String, userLocation: CLLocationCoordinate2D?) async -> PlaceSearchOutcome {
        if await MapKitRateLimitState.shared.isRateLimited() {
            return PlaceSearchOutcome(results: [], wasRateLimited: true)
        }
        
        let region = makeSearchRegion(around: userLocation)
        
        // Prefer direct MKLocalSearch first so we always return quickly.
        let directSearchOutcome = await performMapSearch(query: query, region: region)
        var mapItems = directSearchOutcome.items
        var wasRateLimited = directSearchOutcome.wasRateLimited
        
        // Enrich with completions only when direct search yields nothing.
        if mapItems.isEmpty && !wasRateLimited {
            let completionOutcome = await completionMapItems(query: query, region: region)
            mapItems.append(contentsOf: completionOutcome.items)
            wasRateLimited = completionOutcome.wasRateLimited
        }
        
        let dedupedMapItems = deduplicatedMapItems(mapItems)
        
        let mappedResults = dedupedMapItems
            .prefix(maxReturnedPlaces)
            .enumerated()
            .compactMap { index, item in
                mapItemToSearchResult(item, rank: index)
            }
        
        let stylesByResultID = mappedResults.reduce(into: [String: SearchResultVisualStyle]()) { dictionary, mappedResult in
            if let style = mappedResult.visualStyle {
                dictionary[mappedResult.result.id] = style
            }
            }
        
        if !stylesByResultID.isEmpty {
            await MainActor.run {
                SearchResultVisualStyleStore.shared.setStyles(stylesByResultID)
            }
        }
        
        return PlaceSearchOutcome(
            results: mappedResults.map(\.result),
            wasRateLimited: wasRateLimited
        )
    }
    
    private func completionMapItems(query: String, region: MKCoordinateRegion?) async -> MapKitSearchOutcome {
        let completer = await MainActor.run { MapKitCompleterClient() }
        let completions = await completer.fetchCompletions(query: query, region: region, timeout: 0.6)
        return await resolveMapItems(for: completions, region: region)
    }
    
    private func performMapSearch(query: String, region: MKCoordinateRegion?) async -> MapKitSearchOutcome {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let region {
            request.region = region
        }
        
        do {
            let response = try await MKLocalSearch(request: request).start()
            return MapKitSearchOutcome(items: response.mapItems, wasRateLimited: false)
        } catch {
            let isRateLimited = await handleMapKitSearchError(error, context: "search")
            return MapKitSearchOutcome(items: [], wasRateLimited: isRateLimited)
        }
    }
    
    private func resolveMapItems(for completions: [MKLocalSearchCompletion], region: MKCoordinateRegion?) async -> MapKitSearchOutcome {
        var items: [MKMapItem] = []
        var wasRateLimited = false
        
        for completion in completions.prefix(maxCompletionRequests) {
            if Task.isCancelled || wasRateLimited {
                break
            }
            
            let request = MKLocalSearch.Request(completion: completion)
            request.resultTypes = [.address, .pointOfInterest]
            if let region {
                request.region = region
            }
            
            do {
                let response = try await MKLocalSearch(request: request).start()
                if let first = response.mapItems.first {
                    items.append(first)
                }
            } catch {
                wasRateLimited = await handleMapKitSearchError(error, context: "completion resolution")
            }
        }
        
        return MapKitSearchOutcome(items: items, wasRateLimited: wasRateLimited)
    }
    
    private func mapItemToSearchResult(_ item: MKMapItem, rank: Int) -> MappedSearchResult? {
        let coordinate = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            return nil
        }
        
        let name = mapItemName(item)
        guard !name.isEmpty else {
            return nil
        }
        
        let type = mapItemType(item)
        let areas = makeAreas(from: item.placemark)
        let score = max(0.01, 1.0 - (Double(rank) * 0.01))
        let identifier = mapItemIdentifier(item)
        let visualStyle = mapItemVisualStyle(for: item)
        
        return MappedSearchResult(
            result: SearchResult(
                type: type,
                tokens: [],
                name: name,
                id: identifier,
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                street: cleaned(item.placemark.thoroughfare),
                houseNumber: cleaned(item.placemark.subThoroughfare),
                zip: cleaned(item.placemark.postalCode),
                areas: areas,
                score: score
            ),
            visualStyle: visualStyle
        )
    }

    private func mapItemVisualStyle(for item: MKMapItem) -> SearchResultVisualStyle? {
        guard item.pointOfInterestCategory != nil else {
            return nil
        }
        
        let categoryKey = item.pointOfInterestCategory?.rawValue.lowercased() ?? ""
        
        if categoryKey.contains("restaurant") || categoryKey.contains("bakery") || categoryKey.contains("cafe") || categoryKey.contains("foodmarket") || categoryKey.contains("brewery") || categoryKey.contains("winery") || categoryKey.contains("distillery") {
            return SearchResultVisualStyle(symbolName: "fork.knife", color: .yellow)
        }
        
        if categoryKey.contains("airport") {
            return SearchResultVisualStyle(symbolName: "airplane", color: .blue)
        }
        
        if categoryKey.contains("hotel") || categoryKey.contains("campground") || categoryKey.contains("rvpark") || categoryKey.contains("marina") {
            return SearchResultVisualStyle(symbolName: "bed.double.fill", color: .teal)
        }
        
        if categoryKey.contains("parking") {
            return SearchResultVisualStyle(symbolName: "parkingsign.circle.fill", color: .indigo)
        }
        
        if categoryKey.contains("hospital") || categoryKey.contains("pharmacy") || categoryKey.contains("fitness") || categoryKey.contains("spa") {
            return SearchResultVisualStyle(symbolName: "cross.case.fill", color: .red)
        }
        
        if categoryKey.contains("school") || categoryKey.contains("university") || categoryKey.contains("library") {
            return SearchResultVisualStyle(symbolName: "book.fill", color: .brown)
        }
        
        if categoryKey.contains("movie") || categoryKey.contains("theater") || categoryKey.contains("museum") || categoryKey.contains("music") || categoryKey.contains("nightlife") || categoryKey.contains("amusement") || categoryKey.contains("aquarium") || categoryKey.contains("zoo") {
            return SearchResultVisualStyle(symbolName: "ticket.fill", color: .purple)
        }
        
        if categoryKey.contains("park") || categoryKey.contains("beach") || categoryKey.contains("hiking") || categoryKey.contains("skiing") || categoryKey.contains("swimming") || categoryKey.contains("surfing") || categoryKey.contains("golf") || categoryKey.contains("tennis") || categoryKey.contains("soccer") || categoryKey.contains("basketball") || categoryKey.contains("baseball") {
            return SearchResultVisualStyle(symbolName: "figure.outdoor.cycle", color: .green)
        }
        
        if categoryKey.contains("publictransport") || categoryKey.contains("station") {
            return SearchResultVisualStyle(symbolName: "tram.fill", color: .mint)
        }
        
        if categoryKey.contains("gasstation") || categoryKey.contains("evcharger") || categoryKey.contains("carrental") || categoryKey.contains("automotive") {
            return SearchResultVisualStyle(symbolName: "car.fill", color: .cyan)
        }
        
        if categoryKey.contains("bank") || categoryKey.contains("atm") || categoryKey.contains("postoffice") || categoryKey.contains("mailbox") || categoryKey.contains("police") || categoryKey.contains("firestation") {
            return SearchResultVisualStyle(symbolName: "building.columns.fill", color: .blue)
        }
        
        return SearchResultVisualStyle(symbolName: "mappin", color: .blue)
    }
    
    private func mapItemType(_ item: MKMapItem) -> LocationType {
        if item.pointOfInterestCategory != nil {
            return .place
        }
        
        if cleaned(item.placemark.thoroughfare) != nil || cleaned(item.placemark.subThoroughfare) != nil || cleaned(item.placemark.postalCode) != nil {
            return .adress
        }
        
        return .place
    }
    
    private func mapItemName(_ item: MKMapItem) -> String {
        let type = mapItemType(item)
        
        if let name = cleaned(item.name) {
            if type == .place {
                return name
            }
            
            if let street = cleaned(item.placemark.thoroughfare) {
                let houseNumber = cleaned(item.placemark.subThoroughfare) ?? ""
                let addressPrefix = (street + " " + houseNumber).trimmingCharacters(in: .whitespacesAndNewlines)
                if !addressPrefix.isEmpty {
                    return addressPrefix
                }
            }
            
            return name
        }
        
        if let title = cleaned(item.placemark.title) {
            return title
        }
        
        return ""
    }
    
    private func mapItemIdentifier(_ item: MKMapItem) -> String {
        let coordinate = item.placemark.coordinate
        let roundedLatitude = String(format: "%.6f", coordinate.latitude)
        let roundedLongitude = String(format: "%.6f", coordinate.longitude)
        let normalizedName = mapItemName(item).lowercased()
        return "mk:\(roundedLatitude),\(roundedLongitude):\(normalizedName)"
    }
    
    private func makeAreas(from placemark: MKPlacemark) -> [SearchResult.Area] {
        var uniqueAreaNames = Set<String>()
        var areaItems: [(name: String, level: Int)] = []
        
        func appendArea(_ value: String?, level: Int) {
            guard let cleanedValue = cleaned(value) else {
                return
            }
            
            let normalized = cleanedValue.lowercased()
            guard !uniqueAreaNames.contains(normalized) else {
                return
            }
            
            uniqueAreaNames.insert(normalized)
            areaItems.append((cleanedValue, level))
        }
        
        appendArea(placemark.locality, level: 8)
        appendArea(placemark.subLocality, level: 9)
        appendArea(placemark.subAdministrativeArea, level: 6)
        appendArea(placemark.administrativeArea, level: 4)
        appendArea(placemark.country, level: 2)
        
        return areaItems.enumerated().map { index, item in
            SearchResult.Area(
                name: item.name,
                adminLevel: item.level,
                matched: index == 0,
                default: index == 0 ? true : nil
            )
        }
    }
    
    private func deduplicated(results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        var dedupedResults: [SearchResult] = []
        
        for result in results {
            if seen.contains(result.id) {
                continue
            }
            
            seen.insert(result.id)
            dedupedResults.append(result)
        }
        
        return dedupedResults
    }
    
    private func sortedByClosestDistance(_ results: [SearchResult], userLocation: CLLocationCoordinate2D?) -> [SearchResult] {
        guard let userLocation else {
            return results
        }
        
        let userCLLocation = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        
        return results.sorted { lhs, rhs in
            let lhsDistanceMeters = Int(distance(from: userCLLocation, to: lhs).rounded())
            let rhsDistanceMeters = Int(distance(from: userCLLocation, to: rhs).rounded())
            
            if lhsDistanceMeters != rhsDistanceMeters {
                return lhsDistanceMeters < rhsDistanceMeters
            }
            
            if lhs.type != rhs.type {
                return lhs.type == .stop
            }
            
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    private func distance(from userLocation: CLLocation, to result: SearchResult) -> CLLocationDistance {
        let coordinate = CLLocationCoordinate2D(latitude: result.lat, longitude: result.lon)
        
        if !CLLocationCoordinate2DIsValid(coordinate) || (result.lat == 0.0 && result.lon == 0.0) {
            return .greatestFiniteMagnitude
        }
        
        let resultLocation = CLLocation(latitude: result.lat, longitude: result.lon)
        return userLocation.distance(from: resultLocation)
    }
    
    private func deduplicatedMapItems(_ items: [MKMapItem]) -> [MKMapItem] {
        var seen = Set<String>()
        var dedupedItems: [MKMapItem] = []
        
        for item in items {
            let identifier = mapItemIdentifier(item)
            if seen.contains(identifier) {
                continue
            }
            
            seen.insert(identifier)
            dedupedItems.append(item)
        }
        
        return dedupedItems
    }
    
    private func makeSearchRegion(around location: CLLocationCoordinate2D?) -> MKCoordinateRegion? {
        guard let location else {
            return nil
        }
        
        return MKCoordinateRegion(
            center: location,
            latitudinalMeters: 35_000,
            longitudinalMeters: 35_000
        )
    }
    
    private func cleaned(_ text: String?) -> String? {
        guard let text else {
            return nil
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func handleMapKitSearchError(_ error: Error, context: String) async -> Bool {
        let nsError = error as NSError
        
        if isMapKitRateLimitError(nsError) {
            await MapKitRateLimitState.shared.markRateLimited(resetAfter: extractMapKitResetDelay(from: nsError))
            print("map \(context) rate-limited: \(nsError.localizedDescription)")
            return true
        }
        
        print("map \(context) error: \(nsError.localizedDescription)")
        return false
    }
    
    private func isMapKitRateLimitError(_ error: NSError) -> Bool {
        if error.domain == MKErrorDomain && error.code == 3 {
            return true
        }
        
        if error.domain == "GEOErrorDomain" && error.code == -3 {
            return true
        }
        
        if error.userInfo["timeUntilReset"] != nil {
            return true
        }
        
        let description = error.localizedDescription.lowercased()
        return description.contains("throttled") || description.contains("rate limit")
    }
    
    private func extractMapKitResetDelay(from error: NSError) -> TimeInterval? {
        if let reset = error.userInfo["timeUntilReset"] as? NSNumber {
            return reset.doubleValue
        }
        
        if let details = error.userInfo["details"] as? [NSDictionary],
           let firstDetail = details.first,
           let reset = firstDetail["timeUntilReset"] as? NSNumber {
            return reset.doubleValue
        }
        
        return nil
    }
}

private struct MappedSearchResult {
    let result: SearchResult
    let visualStyle: SearchResultVisualStyle?
}

private struct MapKitSearchOutcome {
    let items: [MKMapItem]
    let wasRateLimited: Bool
}

private struct PlaceSearchOutcome {
    let results: [SearchResult]
    let wasRateLimited: Bool
}

actor MapKitRateLimitState {
    static let shared = MapKitRateLimitState()
    
    private var rateLimitedUntil: Date? = nil
    
    func isRateLimited(now: Date = Date()) -> Bool {
        guard let rateLimitedUntil else {
            return false
        }
        
        return now < rateLimitedUntil
    }
    
    func markRateLimited(resetAfter: TimeInterval?) {
        let resetSeconds = max(1.0, resetAfter ?? 4.0)
        let newLimitDate = Date().addingTimeInterval(resetSeconds)
        
        if let currentLimitDate = rateLimitedUntil {
            if newLimitDate > currentLimitDate {
                rateLimitedUntil = newLimitDate
            }
        } else {
            rateLimitedUntil = newLimitDate
        }
    }
}

@MainActor
private final class MapKitCompleterClient: NSObject, MKLocalSearchCompleterDelegate {
    private let completer: MKLocalSearchCompleter = {
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        return completer
    }()
    
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?
    private var timeoutWorkItem: DispatchWorkItem?
    
    override init() {
        super.init()
        completer.delegate = self
    }
    
    func fetchCompletions(
        query: String,
        region: MKCoordinateRegion?,
        timeout: TimeInterval = 0.3
    ) async -> [MKLocalSearchCompletion] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        if let region {
            completer.region = region
        }
        
        return await withCheckedContinuation { continuation in
            resolvePendingContinuation(with: [])
            self.continuation = continuation
            
            timeoutWorkItem?.cancel()
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.resolvePendingContinuation(with: self.completer.results)
            }
            timeoutWorkItem = timeoutItem
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
            
            completer.queryFragment = query
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        resolvePendingContinuation(with: completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("map completer error: \(error.localizedDescription)")
        resolvePendingContinuation(with: [])
    }
    
    private func resolvePendingContinuation(with results: [MKLocalSearchCompletion]) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        
        guard let continuation else {
            return
        }
        
        self.continuation = nil
        continuation.resume(returning: results)
    }
}
