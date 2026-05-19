//
//  CreditsView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.06.2025.
//

import SwiftUI

struct CreditsView: View {
    private let creditItems = [
        CreditItem(name: "Constantin Clerc", credit: String(localized: "Développeur Principal"), imageURL: "https://avatars.githubusercontent.com/u/102235607?v=4", url: "https://github.com/c22dev"),
        CreditItem(name: "Valentin Busi Dias", credit: String(localized: "Conseiller intuitivité et design"), imageURL: "https://cclerc.ch/lux-assets/credits/val.png", url: "https://cclerc.ch/val"),
        CreditItem(name: "Michail Kiourkos", credit: String(localized: "Conseiller intuitivité et design"), imageURL: "https://cclerc.ch/lux-assets/credits/michail.jpeg", url: "https://www.linkedin.com/in/michail-kiourkos-42025338a/"),
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    VStack(spacing: 16) {
                        creditsCard
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
    
    private var creditsCard: some View {
        SettingsCard {
            Section {
                ForEach(Array(creditItems.enumerated()), id: \.offset) { index, item in
                    Button(action: {
                        guard let actualURL = URL(string: item.url) else { return }
                        UIApplication.shared.open(actualURL, options: [:], completionHandler: nil)
                    }) {
                        WebCreditCell(
                            name: item.name,
                            credit: item.credit,
                            imageURL: item.imageURL
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if index < creditItems.count - 1 {
                        Divider()
                            .padding(.leading, 82)
                    }
                }
                
            } header: {
                SectionHeader(
                    icon: "person.3.fill",
                    iconColor: .blue,
                    title: String(localized: "Crédits"),
                    subtitle: String(localized: "Ci-dessous une liste des crédits de l'application.")
                )
            }
        }
    }
}

struct CreditItem {
    let name: String
    let credit: String
    let imageURL: String
    let url: String
}

struct WebCreditCell: View {
    var name: String
    var credit: String
    var imageURL: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(credit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right.square")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
