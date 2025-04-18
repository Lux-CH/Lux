//
//  TabsView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI
import BubbleBar

struct TabsView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        BubbleBarView(selectedTab: $selectedTab) {
            HomeView()
                .tabBarItem(
                    label: { Label("Home", systemImage: "square.grid.3x3") },
                    accessibilityLabel: "Home"
                )
            
            StopsView()
                .tabBarItem(
                    label: { Label("Stops", systemImage: "signpost.right") },
                    accessibilityLabel: "Stops"
                )
            
            OnboardView()
                .tabBarItem(
                    label: { Label("Onboard", systemImage: "location.north") },
                    accessibilityLabel: "Onboard"
                )
            
            TripPlannerView()
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
    TabsView()
}
