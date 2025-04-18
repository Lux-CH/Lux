//
//  HomeView.swift
//  Lux
//
//  Created by Constantin Clerc on 18.04.2025.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(maxHeight: .infinity)
                        .frame(height: 215)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 40,
                                bottomTrailingRadius: 40,
                                topTrailingRadius: 0,
                                style: .continuous
                            )
                        )
                    
                    HomeHeaderView()
                        .padding(.top, 65)
                }
                .ignoresSafeArea(edges: .top)
                
                ZStack {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(maxHeight: .infinity)
                        .clipShape(
                            .rect(
                                topLeadingRadius: 38,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius: 38,
                                style: .continuous
                            )
                        )
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}


#Preview {
    HomeView()
}
