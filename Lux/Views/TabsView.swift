//
//  TabsView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI

struct TabsView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        TabView() {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "square.grid.3x3")
                }
            
            StopsView()
                .tabItem {
                    Label("Stops", systemImage: "signpost.right")
                }
            
            OnboardView()
                .tabItem {
                    Label("Onboard", systemImage: "location.north")
                }
            
            TripPlannerView()
                .tabItem {
                    Label("Trip", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath.fill")
                }
            
            TicketsView()
                .tabItem {
                    Label("Tickets", systemImage: "ticket")
                }
        }
    }
}

#Preview {
    TabsView()
}
