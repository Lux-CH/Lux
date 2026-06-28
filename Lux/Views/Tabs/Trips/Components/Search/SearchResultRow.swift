//
//  SearchResultRow.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//

import SwiftUI
import CoreLocation
import LuxCom

struct SearchResultRow: View {
    @EnvironmentObject var locationManager: LocationManager
    @ObservedObject private var visualStyleStore = SearchResultVisualStyleStore.shared
    @ObservedObject private var openStateStore = SearchResultOpenStateStore.shared
    let result: SearchResult
    
    private func getIconForType(_ type: LocationType)-> (String, Color) {
        switch type{
        case .adress:
            return ("mappin", .red)
        case .place:
            return ("building.fill", .blue)
        case .stop:
            return ("signpost.right.fill", .accentColor)
        }
    }
    
    private func formattedAddress() -> String? {
        var components: [String] = []

        if let street = result.street {
            var streetComponent = street
            if let houseNumber = result.houseNumber {
                streetComponent += " " + houseNumber
            }
            components.append(streetComponent)
        }

        let city = result.areas.first(where: { $0.matched })?.name
            ?? result.areas.first(where: { $0.default == true })?.name
        if let city {
            components.append(city)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    private func relevantArea() -> String? {
        if result.type == .stop {
            return nil
        }
        
        if let matchedArea = result.areas.first(where: { $0.matched }) {
            return matchedArea.name
        } else if let defaultArea = result.areas.first(where: { $0.default == true }) {
            return defaultArea.name
        } else if !result.areas.isEmpty {
            return result.areas.sorted(by: { $0.adminLevel < $1.adminLevel }).first?.name
        }
        
        return nil
    }
    
    private func iconStyleForResult() -> (String, Color) {
        if let style = visualStyleStore.style(for: result.id), result.type != .stop {
            return (style.symbolName, style.color)
        }
        
        return getIconForType(result.type)
    }
    
    var body: some View {
        HStack(spacing: 14) {
            let (iconName, iconColor) = iconStyleForResult()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 38, height: 38)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)

                if result.type != .adress, let address = formattedAddress() {
                    Text(address)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let area = relevantArea() {
                    Text(area)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if result.type == .place, let openState = openStateStore.openState(for: result.id) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(openState.color)
                            .frame(width: 6, height: 6)
                        Text(openState.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(openState.color)
                    }
                    .padding(.top, 1)
                }
            }

            Spacer()

            if let currentLoc = locationManager.location, !(result.lat == 0 && result.lon == 0) {
                let distance = currentLoc.distance(from: CLLocation(latitude: result.lat, longitude: result.lon))
                Text(formatDistance(distance))
                    .font(.system(size: 12))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .contentShape(Rectangle())
    }
}
