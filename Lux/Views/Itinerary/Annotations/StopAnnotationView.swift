//
//  StopAnnotationView.swift
//  Lux
//
//  Created by Constantin Clerc on 23.04.2025.
//

import SwiftUI
import LuxCom
import CoreLocation

struct StopAnnotation: Identifiable {
    let id = UUID()
    let place: Place
    let coordinate: CLLocationCoordinate2D
    let color: Color
    let isTerminal: Bool
    let isIntermediate: Bool
    
    init(place: Place, color: Color, isTerminal: Bool = false, isIntermediate: Bool = false) {
        var modifiedPlace = place
        if Locale.current.language.languageCode?.identifier != "en" {
            switch place.name {
            case "START":
                modifiedPlace.name = "Début"
            case "END":
                modifiedPlace.name = "Fin"
            default:
                break
            }
        }
        
        self.place = modifiedPlace
        self.coordinate = CLLocationCoordinate2D(latitude: place.lat, longitude: place.lon)
        self.color = color
        self.isTerminal = isTerminal
        self.isIntermediate = isIntermediate
    }
}

struct StopAnnotationView: View {
    let annotation: StopAnnotation
    let isTerminal: Bool
    @State private var showPopover = false
    @State private var showExpandedStop = false
    @Binding var showSheet: Bool
    
    private let circleSize: CGFloat = 16
    private let terminalSize: CGFloat = 20
    private let intermediateSize: CGFloat = 10
    private let hitAreaSize: CGFloat = 44
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.clear
                .frame(width: hitAreaSize, height: hitAreaSize)
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isAnimating = true
                        showSheet = false
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isAnimating = false
                        showPopover = true
                    }
                }
            
            if isTerminal || annotation.isTerminal {
                Circle()
                    .fill(annotation.color.opacity(0.15))
                    .frame(width: terminalSize + 10, height: terminalSize + 10)
            }
            
            Circle()
                .fill(.white)
                .frame(
                    width: getCircleSize(),
                    height: getCircleSize()
                )
                .overlay {
                    Circle()
                        .stroke(annotation.color, lineWidth: isTerminal || annotation.isTerminal ? 3 : 1)
                }
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
        }
        .popover(isPresented: $showPopover) {
            StopPopoverView(place: annotation.place, color: annotation.color, onNavigate: {
                showPopover = false
                showExpandedStop = true
            })
            .presentationCompactAdaptation(.popover)
        }
        .fullScreenCover(isPresented: $showExpandedStop) {
            ItineraryStopDetailView(stop: annotation.place)
        }
        .onChange(of: showPopover) {
            if !showPopover && !showExpandedStop {
                showSheet = true
            }
        }
        .onChange(of: showExpandedStop) {
            if !showExpandedStop {
                showSheet = true
            }
        }
    }
    
    private func getCircleSize() -> CGFloat {
        if isTerminal || annotation.isTerminal {
            return terminalSize
        } else if annotation.isIntermediate {
            return intermediateSize
        } else {
            return circleSize
        }
    }
}

struct StopPopoverView: View {
    let place: Place
    let color: Color
    let onNavigate: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(place.name)
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                if let arrival = place.arrival {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(color)
                        Text("Arrivée prévue : \(formatTime(arrival))")
                            .fontWeight(.medium)
                    }
                }
                else if let departure = place.departure {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .foregroundColor(color)
                        Text("Départ à : \(formatTime(departure))")
                            .fontWeight(.medium)
                    }
                }
                
                if let track = place.track {
                    HStack(spacing: 6) {
                        Image(systemName: "train.side.front.car")
                            .foregroundColor(color)
                        Text(getTrackType(track))
                            .fontWeight(.medium)
                    }
                }
            }
            .font(.subheadline)
            
            Button {
                onNavigate()
            } label: {
                HStack {
                    Text("Autres départs")
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .foregroundColor(colorScheme == .dark && color == .white ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
        .padding()
        .frame(minWidth: 250)
        .background(Color(.secondarySystemBackground).opacity(0.8))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
