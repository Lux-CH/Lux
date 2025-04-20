//
//  TabsView.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI

struct TabsView: View {
    @State private var selectedTab = 1
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            StopsView()
                .tabItem {
                    Label("Stops", systemImage: "signpost.right")
                }
                .tag(0)
            
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "square.grid.3x3")
                }
                .tag(1)
            
            TicketsView()
                .tabItem {
                    Label("Tickets", systemImage: "ticket")
                }
                .tag(2)
        }
    }
}

#Preview {
    TabsView()
}
