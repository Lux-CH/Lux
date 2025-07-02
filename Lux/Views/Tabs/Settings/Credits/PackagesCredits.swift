//
//  CreditsView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.06.2025.
//

import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section(
                content: {
                    WebCreditCell(
                        name: "Constantin Clerc", credit: "Développeur Principal", imageURL: "https://avatars.githubusercontent.com/u/102235607?v=4",
                        url: "https://github.com/c22dev")
                    WebCreditCell(
                        name: "Philippe Weidmann", credit: "Données des perturbations",
                        imageURL: "https://avatars.githubusercontent.com/u/5843044?v=4", url: "https://apps.apple.com/fr/app/tpg-max/id1373332448")
                    WebCreditCell(
                        name: "Paul Hudson", credit: "CodeScanner — MIT", imageURL: "https://avatars.githubusercontent.com/u/190200?v=4",
                        url: "https://github.com/twostraws/CodeScanner")
                    WebCreditCell(
                        name: "Raphaël Mor", credit: "Polyline — MIT", imageURL: "https://avatars.githubusercontent.com/u/772779?v=4",
                        url: "https://github.com/raphaelmor/Polyline")
                    WebCreditCell(
                        name: "Yubo Qin", credit: "SymbolPicker — MIT", imageURL: "https://avatars.githubusercontent.com/u/6781789?v=4",
                        url: "https://github.com/xnth97/SymbolPicker")
                    WebCreditCell(name: "Edon Valdman", credit: "SwiftUIMessage — MIT", imageURL: "https://avatars.githubusercontent.com/u/22782929?v=4", url: "https://github.com/edonv/SwiftUIMessage")
                    WebCreditCell(name: "Hirotakan", credit: "MessagePacker — MIT", imageURL: "https://avatars.githubusercontent.com/u/2901342?v=4", url: "https://github.com/hirotakan/MessagePacker")
                    WebCreditCell(name: "Aether Jones", credit: "GlowGetter — MIT", imageURL: "https://avatars.githubusercontent.com/u/64797587?v=4", url: "https://github.com/Aeastr/GlowGetter")
                    
                },
                footer: {Text("Ci-dessus une liste des crédits de l'application, notamment des différents autres modules utilisés par Lux.")})
        }
        .navigationTitle("Crédits")
        .navigationBarTitleDisplayMode(.inline)
        //        .listStyle(GroupedListStyle())
    }
}

struct WebCreditCell: View {
    var name: String
    var credit: String
    var imageURL: String
    var url: String
    var body: some View {
        HStack(alignment: .center) {
            AsyncImage(url: URL(string: imageURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(.white)
            } placeholder: {
                ProgressView()
            }
            .frame(width: 50, height: 50)
            .cornerRadius(.infinity)
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.headline)
                Text(credit)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                guard let actualURL = URL(string: url) else {
                  return //be safe
                }
                UIApplication.shared.open(actualURL, options: [:], completionHandler: nil)
            }) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}
