//
//  IndividualStopView.swift
//  Lux
//
//  Created by Constantin Clerc on 19.04.2025.
//

import SwiftUI
import LuxCom

struct IndividualStopView: View {
    @State var stop: SearchResult
    let forceLC: Bool

    private var topSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.safeAreaInsets.top ?? 44
    }

    init(stop: SearchResult, forceLC: Bool = false) {
        self._stop = State(initialValue: stop)
        self.forceLC = forceLC
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.secondarySystemBackground).opacity(0.8)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                StopHeaderView(stop: stop)
                    .padding(.top, topSafeAreaInset + 52)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                Divider()
                VStack(alignment: .center) {
                    StopView(stop: stop, maxGroupsToShow: 50, fromStops: true, forceLC: forceLC)
                        .padding(.top, -5)
                }
            }
            .edgesIgnoringSafeArea(.vertical)
        }
    }
}
