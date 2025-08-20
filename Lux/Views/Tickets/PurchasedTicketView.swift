//
//  PurchasedTicketView.swift
//  Lux
//
//  Created by Constantin Clerc on 19.08.2025.
//

import SwiftUI

struct PurchasedTicketView: View {
    let ticket: PurchasedTicket
    let currentDate: Date

    private var countdownText: String {
        let remaining = ticket.expiry.timeIntervalSince(currentDate)
        let minutes = max(0, Int(remaining) / 60)
        return "\(minutes)'"
    }
    
    var body: some View {
        Divider()
        Button(action: {
            if let smsURL = URL(string: "sms:788") {
                UIApplication.shared.open(smsURL)
            }
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .center) {
                    Text(countdownText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(ticket.ticketName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
