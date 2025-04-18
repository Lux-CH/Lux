//
//  ContentView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI
import BubbleBar

struct ContentView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        BubbleBarView(selectedTab: $selectedTab) {
            VStack {
                if let location = locationManager.location {
                    Text("You're at: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                } else {
                    Text("Getting location...")
                }
            }
            
                .tabBarItem(
                    label: { Label("Home", systemImage: "square.grid.3x3") },
                    accessibilityLabel: "Home"
                )
            
            Text("Srotoet")
                .tabBarItem(
                    label: { Label("Stops", systemImage: "signpost.right") },
                    accessibilityLabel: "Stops"
                )
            
            Text("Sreeotoet")
                .tabBarItem(
                    label: { Label("Onboard", systemImage: "location.north") },
                    accessibilityLabel: "Onboard"
                )
            
            Text("eeiei")
                .tabBarItem (
                    label: { Label("Trip", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill") },
                    accessibilityLabel: "Trip"
                )
            
            Text("tickets view")
                .tabBarItem (
                    label : { Label("Tickets", systemImage: "ticket") },
                    accessibilityLabel: "Tickets"
                )
        }
        .bubbleBarStyle(.desert)
    }
}

#Preview {
    ContentView()
}
