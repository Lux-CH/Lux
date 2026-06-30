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
    private let maxReturnedPlaces = 10
    private let scorer = SearchResultScorer()
    
    func search(query: String, userLocation: CLLocationCoordinate2D?) async -> [SearchResult] {
        async let stopSearchResults = searchStops(query: query, userLocation: userLocation)
        async let placeSearchOutcome = searchPlaces(query: query, userLocation: userLocation)
        
        let stopResults = await stopSearchResults
        let placeOutcome = await placeSearchOutcome
        
        var mergedResults = stopResults + placeOutcome.results
        
        if placeOutcome.wasRateLimited {
            let luxFallback = await searchLuxFallbackAll(query: query, userLocation: userLocation)
            mergedResults.append(contentsOf: luxFallback)
        }
        
        let deduplicatedByID = deduplicated(results: mergedResults)
        let rankedResults = scorer.ranked(deduplicatedByID, query: query, userLocation: userLocation)
        return deduplicatedByNameAndProximity(rankedResults)
    }
    
    private func searchStops(query: String, userLocation: CLLocationCoordinate2D?) async -> [SearchResult] {
        do {
            if let userLocation {
                return try await LuxData.geocode(
                    text: query,
                    type: .stop,
                    place: (userLocation.latitude, userLocation.longitude),
                    placeBias: 2
                )
            }
            return try await LuxData.geocode(text: query, type: .stop)
        } catch {
            print("stop geocode error: \(error.localizedDescription)")
            return []
        }
    }
    
    private func searchLuxFallbackAll(query: String, userLocation: CLLocationCoordinate2D?) async -> [SearchResult] {
        do {
            if let userLocation {
                return try await LuxData.geocode(
                    text: query,
                    place: (userLocation.latitude, userLocation.longitude),
                    placeBias: 2
                )
            }
            
            return try await LuxData.geocode(text: query)
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

        let completer = await MainActor.run { MapKitCompleterClient.shared }
        let completions = await completer.fetchCompletions(query: query, region: region)

        if !completions.isEmpty {
            let results = await MainActor.run { mapCompletionsToOutcome(completions) }
            return PlaceSearchOutcome(results: results, wasRateLimited: false)
        }

        let directOutcome = await performMapSearch(query: query, region: region)
        if directOutcome.wasRateLimited {
            return PlaceSearchOutcome(results: [], wasRateLimited: true)
        }

        let resolvedResults = await makeResolvedResults(from: directOutcome.items)
        return PlaceSearchOutcome(results: resolvedResults, wasRateLimited: false)
    }

    @MainActor
    private func mapCompletionsToOutcome(_ completions: [MKLocalSearchCompletion]) -> [SearchResult] {
        var results: [SearchResult] = []
        var completionsByID: [String: MKLocalSearchCompletion] = [:]
        var stylesByID: [String: SearchResultVisualStyle] = [:]
        var openStatesByID: [String: POIOpenState] = [:]
        var seenIDs = Set<String>()

        for (index, completion) in completions.prefix(maxReturnedPlaces).enumerated() {
            guard let title = cleaned(completion.title) else {
                continue
            }

            let subtitle = cleaned(completion.subtitle)
            let identifier = completionIdentifier(title: title, subtitle: subtitle)
            guard !seenIDs.contains(identifier) else {
                continue
            }
            let score = max(0.01, 1.0 - (Double(index) * 0.01))

            if let mapItem = privateMapItem(from: completion) {
                if isMapKitTransitStop(mapItem) {
                    continue
                }
                if let mapped = mapItemToSearchResult(mapItem, rank: index) {
                    seenIDs.insert(identifier)
                    let core = mapped.result
                    results.append(
                        SearchResult(
                            type: mapItem.pointOfInterestCategory != nil ? .place : .adress,
                            tokens: core.tokens,
                            name: title,
                            id: identifier,
                            lat: core.lat,
                            lon: core.lon,
                            level: core.level,
                            street: core.street,
                            houseNumber: core.houseNumber,
                            zip: core.zip,
                            areas: core.areas.isEmpty ? makeAreas(fromSubtitle: subtitle) : core.areas,
                            score: score
                        )
                    )
                    if let style = mapped.visualStyle {
                        stylesByID[identifier] = style
                    }
                    if let state = mapped.openState {
                        openStatesByID[identifier] = state
                    }
                    continue
                }
            }

            seenIDs.insert(identifier)
            let isAddress = completionLooksLikeAddress(completion)
            results.append(
                SearchResult(
                    type: isAddress ? .adress : .place,
                    tokens: [],
                    name: title,
                    id: identifier,
                    lat: 0,
                    lon: 0,
                    areas: makeAreas(fromSubtitle: subtitle),
                    score: score
                )
            )
            completionsByID[identifier] = completion
        }

        if !completionsByID.isEmpty {
            MapKitCompletionStore.shared.setCompletions(completionsByID)
        }
        if !stylesByID.isEmpty {
            SearchResultVisualStyleStore.shared.setStyles(stylesByID)
        }
        if !openStatesByID.isEmpty {
            SearchResultOpenStateStore.shared.setOpenStates(openStatesByID)
        }

        return results
    }

    private func privateMapItem(from completion: MKLocalSearchCompletion) -> MKMapItem? {
        let key = "mapItem"
        guard completion.responds(to: NSSelectorFromString(key)) else {
            return nil
        }

        guard let mapItem = completion.value(forKey: key) as? MKMapItem else {
            return nil
        }

        let coordinate = coordinate(of: mapItem)
        guard CLLocationCoordinate2DIsValid(coordinate),
              !(coordinate.latitude == 0 && coordinate.longitude == 0) else {
            return nil
        }

        return mapItem
    }

    private func coordinate(of item: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return item.location.coordinate
        }
        return item.placemark.coordinate
    }

    private func makeResolvedResults(from items: [MKMapItem]) async -> [SearchResult] {
        let filteredMapItems = items.filter { !isMapKitTransitStop($0) }
        let dedupedMapItems = deduplicatedMapItems(filteredMapItems)

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
        let openStatesByResultID = mappedResults.reduce(into: [String: POIOpenState]()) { dictionary, mappedResult in
            if let state = mappedResult.openState {
                dictionary[mappedResult.result.id] = state
            }
        }

        await MainActor.run {
            if !stylesByResultID.isEmpty {
                SearchResultVisualStyleStore.shared.setStyles(stylesByResultID)
            }
            if !openStatesByResultID.isEmpty {
                SearchResultOpenStateStore.shared.setOpenStates(openStatesByResultID)
            }
        }

        return mappedResults.map(\.result)
    }

    func resolve(_ result: SearchResult) async -> SearchResult {
        if result.lat != 0 || result.lon != 0 {
            return result
        }

        guard let completion = await MapKitCompletionStore.shared.completion(for: result.id) else {
            return result
        }

        return await resolveCompletion(completion, for: result)
    }

    @MainActor
    private func resolveCompletion(_ completion: MKLocalSearchCompletion, for result: SearchResult) async -> SearchResult {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first,
                  let mapped = mapItemToSearchResult(item, rank: 0) else {
                return result
            }

            if let style = mapped.visualStyle {
                SearchResultVisualStyleStore.shared.setStyles([result.id: style])
            }
            if let state = mapped.openState {
                SearchResultOpenStateStore.shared.setOpenStates([result.id: state])
            }

            let core = mapped.result
            return SearchResult(
                type: result.type,
                tokens: result.tokens,
                name: result.name.isEmpty ? core.name : result.name,
                id: result.id,
                lat: core.lat,
                lon: core.lon,
                level: core.level,
                street: core.street,
                houseNumber: core.houseNumber,
                zip: core.zip,
                areas: core.areas.isEmpty ? result.areas : core.areas,
                score: result.score
            )
        } catch {
            _ = await handleMapKitSearchError(error, context: "completion resolve")
            return result
        }
    }

    private func performMapSearch(query: String, region: MKCoordinateRegion?) async -> MapKitSearchOutcome {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        request.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.publicTransport])
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
    
    private func mapItemToSearchResult(_ item: MKMapItem, rank: Int) -> MappedSearchResult? {
        let coordinate = coordinate(of: item)
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
        let openState = mapItemOpenState(for: item)

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
            visualStyle: visualStyle,
            openState: openState
        )
    }
    
    private func isMapKitTransitStop(_ item: MKMapItem) -> Bool {
        guard let category = item.pointOfInterestCategory else {
            return false
        }
        
        return category.rawValue.lowercased().contains("publictransport")
    }

    private func mapItemOpenState(for item: MKMapItem) -> POIOpenState? {
        let optsKey = "_openingHoursOptions"
        guard item.responds(to: NSSelectorFromString(optsKey)) else { return nil }
        let opts = item.value(forKey: optsKey) as? UInt64 ?? 0
        guard opts != 0, (opts & 0x001) == 0 else { return nil }

        if (opts & 0x080) != 0 { return .permanentlyClosed }
        if (opts & 0x100) != 0 { return .temporarilyClosed }

        if (opts & 0x040) != 0 { return .closingSoon(at: nil) }
        if (opts & 0x010) != 0 { return .openAllDay }
        if (opts & 0x002) != 0 { return .open(until: nil) }
        if (opts & 0x020) != 0 { return .openingSoon(at: nil) }
        if (opts & 0x004) != 0 || (opts & 0x008) != 0 { return .closed(opensAt: nil) }
        return nil
    }

    private func mapItemVisualStyle(for item: MKMapItem) -> SearchResultVisualStyle? {
        guard let categoryKey = item.pointOfInterestCategory?.rawValue.lowercased() else {
            return nil
        }
        
        func matches(_ tokens: [String]) -> Bool {
            tokens.contains { categoryKey.contains($0) }
        }
        
        if matches(["restaurant", "bakery", "cafe", "foodmarket", "brewery", "winery", "distillery"]) {
            return SearchResultVisualStyle(symbolName: "fork.knife", color: .yellow)
        }
        
        if matches(["airport"]) {
            return SearchResultVisualStyle(symbolName: "airplane", color: .blue)
        }
        
        if matches(["hotel", "campground", "rvpark", "marina"]) {
            return SearchResultVisualStyle(symbolName: "bed.double.fill", color: .teal)
        }
        
        if matches(["parking"]) {
            return SearchResultVisualStyle(symbolName: "parkingsign.circle.fill", color: .indigo)
        }
        
        if matches(["hospital", "pharmacy", "fitnesscenter", "spa"]) {
            return SearchResultVisualStyle(symbolName: "cross.case.fill", color: .red)
        }
        
        if matches(["library", "planetarium", "school", "university"]) {
            return SearchResultVisualStyle(symbolName: "book.fill", color: .brown)
        }
        
        if matches(["museum", "musicvenue", "theater", "movietheater", "nightlife"]) {
            return SearchResultVisualStyle(symbolName: "theatermasks.fill", color: .purple)
        }
        
        if matches(["castle", "fortress", "landmark", "nationalmonument"]) {
            return SearchResultVisualStyle(symbolName: "building.columns.fill", color: .brown)
        }
        
        if matches(["amusementpark", "aquarium", "beach", "fairground", "nationalpark", "park", "zoo"]) {
            return SearchResultVisualStyle(symbolName: "tree.fill", color: .green)
        }
        
        if matches(["baseball", "basketball", "bowling", "gokart", "golf", "hiking", "minigolf", "rockclimbing", "skatepark", "skating", "skiing", "soccer", "stadium", "tennis", "volleyball"]) {
            return SearchResultVisualStyle(symbolName: "figure.outdoor.cycle", color: .green)
        }
        
        if matches(["fishing", "kayaking", "surfing", "swimming"]) {
            return SearchResultVisualStyle(symbolName: "water.waves", color: .blue)
        }
        
        if matches(["publictransport"]) {
            return SearchResultVisualStyle(symbolName: "tram.fill", color: .mint)
        }
        
        if matches(["carrental", "gasstation", "evcharger", "automotiverepair"]) {
            return SearchResultVisualStyle(symbolName: "car.fill", color: .cyan)
        }
        
        if matches(["conventioncenter", "store"]) {
            return SearchResultVisualStyle(symbolName: "building.2.fill", color: .blue)
        }
        
        if matches(["bank", "atm", "postoffice", "mailbox"]) {
            return SearchResultVisualStyle(symbolName: "building.columns.fill", color: .blue)
        }
        
        if matches(["firestation", "police"]) {
            return SearchResultVisualStyle(symbolName: "shield.fill", color: .red)
        }
        
        if matches(["animalservice"]) {
            return SearchResultVisualStyle(symbolName: "pawprint.fill", color: .yellow)
        }
        
        if matches(["beauty"]) {
            return SearchResultVisualStyle(symbolName: "sparkles", color: .pink)
        }
        
        if matches(["laundry"]) {
            return SearchResultVisualStyle(symbolName: "washer.fill", color: .cyan)
        }
        
        if matches(["restroom"]) {
            return SearchResultVisualStyle(symbolName: "figure.stand", color: .gray)
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
        let name = cleaned(item.name).flatMap { $0 == "Unknown Location" ? nil : $0 }

        if let name, type == .place {
            return name
        }

        if let street = cleaned(item.placemark.thoroughfare) {
            let houseNumber = cleaned(item.placemark.subThoroughfare) ?? ""
            let addressPrefix = (street + " " + houseNumber).trimmingCharacters(in: .whitespacesAndNewlines)
            if !addressPrefix.isEmpty {
                return addressPrefix
            }
            
        }
        if let name {
            return name
        }
        
        if let title = cleaned(item.placemark.title) {
            return title
        }
        
        return ""
    }
    
    private func mapItemIdentifier(_ item: MKMapItem) -> String {
        let coordinate = coordinate(of: item)
        let roundedLatitude = String(format: "%.6f", coordinate.latitude)
        let roundedLongitude = String(format: "%.6f", coordinate.longitude)
        let normalizedName = mapItemName(item).lowercased()
        return "mk:\(roundedLatitude),\(roundedLongitude):\(normalizedName)"
    }
    
    private func completionIdentifier(title: String, subtitle: String?) -> String {
        let normalizedTitle = title.lowercased()
        let normalizedSubtitle = (subtitle ?? "").lowercased()
        return "mkc:\(normalizedTitle)|\(normalizedSubtitle)"
    }

    private func completionLooksLikeAddress(_ completion: MKLocalSearchCompletion) -> Bool {
        let title = completion.title
        let hasDigits = title.rangeOfCharacter(from: .decimalDigits) != nil
        let subtitleEmpty = cleaned(completion.subtitle) == nil
        return hasDigits || subtitleEmpty
    }

    private func makeAreas(fromSubtitle subtitle: String?) -> [SearchResult.Area] {
        guard let subtitle else {
            return []
        }

        let components = subtitle
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let primary = components.last else {
            return []
        }

        return [
            SearchResult.Area(name: primary, adminLevel: 8, matched: true, default: true)
        ]
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
    
    private func deduplicatedByNameAndProximity(_ results: [SearchResult]) -> [SearchResult] {
        let duplicateDistanceThreshold: CLLocationDistance = 120.0
        var keptByNormalizedName: [String: [SearchResult]] = [:]
        var deduplicated: [SearchResult] = []
        
        for result in results {
            let normalizedName = normalizedName(for: result.name)
            guard !normalizedName.isEmpty else {
                deduplicated.append(result)
                continue
            }
            
            let existing = keptByNormalizedName[normalizedName] ?? []
            let isDuplicate = existing.contains { existingResult in
                areWithinDuplicateThreshold(existingResult, result, threshold: duplicateDistanceThreshold)
            }
            
            if isDuplicate {
                continue
            }
            
            keptByNormalizedName[normalizedName, default: []].append(result)
            deduplicated.append(result)
        }
        
        return deduplicated
    }
    
    private func normalizedName(for name: String) -> String {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let trimmed = folded.trimmingCharacters(in: .whitespacesAndNewlines)
        let punctuationFree = trimmed.replacingOccurrences(
            of: "[^\\p{L}\\p{N}\\s]",
            with: " ",
            options: .regularExpression
        )
        let collapsedSpaces = punctuationFree.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return collapsedSpaces.lowercased()
    }
    
    private func areWithinDuplicateThreshold(
        _ lhs: SearchResult,
        _ rhs: SearchResult,
        threshold: CLLocationDistance
    ) -> Bool {
        let lhsCoordinate = CLLocationCoordinate2D(latitude: lhs.lat, longitude: lhs.lon)
        let rhsCoordinate = CLLocationCoordinate2D(latitude: rhs.lat, longitude: rhs.lon)
        
        guard CLLocationCoordinate2DIsValid(lhsCoordinate),
              CLLocationCoordinate2DIsValid(rhsCoordinate),
              !(lhs.lat == 0.0 && lhs.lon == 0.0),
              !(rhs.lat == 0.0 && rhs.lon == 0.0) else {
            return false
        }
        
        let lhsLocation = CLLocation(latitude: lhs.lat, longitude: lhs.lon)
        let rhsLocation = CLLocation(latitude: rhs.lat, longitude: rhs.lon)
        return lhsLocation.distance(from: rhsLocation) <= threshold
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
    let openState: POIOpenState?
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
private final class MapKitCompleterClient: NSObject {
    static let shared = MapKitCompleterClient()
    
    private let completer: MKLocalSearchCompleter = {
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [.publicTransport])
        return completer
    }()
    
    private var continuation: CheckedContinuation<[MKLocalSearchCompletion], Never>?
    private var expectedQueryFragment = ""
    
    override init() {
        super.init()
        completer.delegate = self
    }
    
    func fetchCompletions(
        query: String,
        region: MKCoordinateRegion?
    ) async -> [MKLocalSearchCompletion] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        if let region {
            completer.region = region
        }
        
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                resolvePendingContinuation(with: [])
                self.continuation = continuation
                self.expectedQueryFragment = query
                
                completer.queryFragment = query
            }
        } onCancel: { [weak self] in
            Task { @MainActor [weak self] in
                self?.resolvePendingContinuation(with: [])
            }
        }
    }
    
    private func resolvePendingContinuation(with results: [MKLocalSearchCompletion]) {
        
        guard let continuation else {
            return
        }
        
        self.continuation = nil
        continuation.resume(returning: results)
    }
}

extension MapKitCompleterClient: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor [weak self] in
            guard self?.expectedQueryFragment == completer.queryFragment else {
                return
            }
            if completer.results.isEmpty && completer.isSearching {
                return
            }
            self?.resolvePendingContinuation(with: completer.results)
        }
    }
    
    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            print("map completer error: \(error.localizedDescription)")
            self?.resolvePendingContinuation(with: [])
        }
    }
}
