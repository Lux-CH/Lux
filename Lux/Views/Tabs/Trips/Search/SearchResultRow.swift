//
//  SearchResultRow.swift
//  Lux
//
//  Created by Constantin Clerc on 29.04.2025.
//

import SwiftUI
import LuxCom

struct SearchResultRow: View {
    let result: SearchResult
    @Environment(\.colorScheme) private var colorScheme
    
    private func getIconForType(_ type: LocationType)-> (String, Color) {
        switch type{
        case .adress:
            return ("mappin.circle.fill", .red)
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
        
        if let zip = result.zip {
            components.append(zip)
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
    
    var body: some View {
        HStack(spacing: 18) {
            let (iconName, iconColor) = getIconForType(result.type)
            
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.name)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                if result.type != .adress, let address = formattedAddress() {
                    Text(address)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                if let area = relevantArea() {
                    Text(area)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                        .padding(.top, 1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .contentShape(Rectangle())
    }
}
