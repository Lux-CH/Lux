//
//  WelcomeView.swift
//  Lux
//
//  Created by Constantin Clerc on 30.07.2025.
//

import SwiftUI
import LuxCom

struct WelcomeView: View {
    @State private var currentPage: Int = 0
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = Settings.shared
    
    @State private var showShortcuts = false
    @State private var showLineScore = false
    @State private var showLuxPass = false

    private let totalPages = 4
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGroupedBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            NavigationStack {
                VStack(spacing: 0) {
                    TabView(selection: $currentPage) {
                        welcomePage
                            .tag(0)
                        transportGuidePage
                            .tag(1)
                        stopsPage
                            .tag(2)
                        finalPage
                            .tag(3)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    
                    bottomControls
                }
                .navigationDestination(isPresented: $showShortcuts) {
                    ShortcutsListView()
                }
                .navigationDestination(isPresented: $showLineScore) {
                    LineScoreView()
                }
                .navigationDestination(isPresented: $showLuxPass) {
                    LuxPassView(showSwisspassOnHome: .constant(false), isFromHome: false)
                        .background(Color(.secondarySystemBackground))
                }
            }
        }
    }
    
    private var bottomControls: some View {
        VStack(spacing: 20) {
            pageIndicators
            navigationButton
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    private var pageIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.primary : Color.primary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }
    
    private var navigationButton: some View {
        Button(action: handleNextTap) {
            HStack(spacing: 8) {
                Image(systemName: isLastPage ? "flag.checkered" : "arrow.right")
                    .font(.system(size: 16, weight: .medium))
                Text(isLastPage ? "Commencer" : "Suivant")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
    }
    
    private var isLastPage: Bool {
        currentPage == totalPages - 1
    }
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            appIconSection
            titleSection
            
            Spacer()
        }
        .padding(.horizontal, 30)
    }
    
    private var appIconSection: some View {
        Group {
            if let icon = Bundle.main.icon {
                Image(uiImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Bienvenue sur")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Lux")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(luxGradient)
            }
            
            Text("Déplacez-vous facilement dans Genève")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var transportGuidePage: some View {
        VStack(spacing: 36) {
            pageHeader(
                icon: "tram.fill",
                title: String(localized: "Guide des transports"),
                subtitle: Text("Apprenez à lire les informations en temps réel")
            )
            
            legendCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var legendCard: some View {
        ModernCard(style: .normal) {
            VStack(alignment: .leading, spacing: 24) {
                legendHeader
                legendItems
            }
        }
    }
    
    private var legendHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Légende des couleurs")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Comprenez l'état de vos transports")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var legendItems: some View {
        VStack(spacing: 20) {
            TransportTimeExplainationItem(
                time: "3'",
                color: .green,
                title: String(localized: "Temps réel"),
                description: String(localized: "Information précise et actualisée"),
                icon: "checkmark.circle.fill"
            )
            
            Divider().opacity(0.3)
            
            TransportTimeExplainationItem(
                time: "4'",
                color: .red,
                title: String(localized: "Retard/Avance"),
                description: String(localized: "Transport en retard ou en avance"),
                icon: "exclamationmark.triangle.fill"
            )
            
            Divider().opacity(0.3)
            
            TransportTimeExplainationItem(
                time: "42'",
                color: .primary,
                title: String(localized: "Horaire théorique"),
                description: String(localized: "Aucune information en temps réel disponible"),
                icon: "clock"
            )
            
            Divider().opacity(0.3)
            
            TransportTimeExplainationItem(
                time: "10:38*",
                color: .primary,
                title: String(localized: "Autre jour"),
                description: String(localized: "Horaire d'un jour différent"),
                icon: "calendar"
            )
        }
    }
    
    private var stopsPage: some View {
        VStack(spacing: 36) {
            pageHeader(
                icon: "signpost.right",
                title: String(localized: "Arrêts"),
                subtitle: Text("Les arrêts sont représentés par l'icône \(Image(systemName: "signpost.right"))")
            )
            
            stopsExampleCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var stopsExampleCard: some View {
        ModernCard(style: .normal) {
            VStack(spacing: 20) {
                stopExampleHeader
                stopPreviewCard
                tipCard
            }
        }
    }
    
    private var stopExampleHeader: some View {
        HStack {
            Image(systemName: "signpost.right")
                .font(.system(size: 18))
                .foregroundColor(.orange)
            
            Text("Exemple d'arrêt")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    private var stopPreviewCard: some View {
        ModernCard(style: .normal) {
            StopPreviewWelcomeView(
                stop: SearchResult(
                    type: .stop,
                    tokens: [],
                    name: "Lancy-Bachet, gare",
                    id: "ch_Parent8587075",
                    lat: 0.0,
                    lon: 0.0,
                    level: 0.0,
                    areas: [],
                    score: 0.0
                )
            )
        }
    }
    
    private var tipCard: some View {
        ModernCard(style: .normal) {
            HStack(spacing: 12) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Astuce")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    Text("Glissez horizontalement pour voir les différentes directions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
        }
    }
    
    private var finalPage: some View {
        VStack(spacing: 36) {
            pageHeader(
                icon: "checkmark",
                title: String(localized: "Tout est prêt !"),
                subtitle: Text("Vous êtes désormais prêt à utiliser Lux.")
            )
            
            customizationCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var customizationCard: some View {
        ModernCard(style: .normal) {
            VStack(alignment: .leading, spacing: 24) {
                customizationHeader
                customizationItems
            }
        }
    }
    
    private var customizationHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintbrush")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Faites de Lux le votre")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Personnalisez Lux pour l'adapter à vos besoins et préférences")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var customizationItems: some View {
        VStack(spacing: 20) {
            CustomisationExplainationButton(
                title: String(localized: "Ajoutez des raccourcis"),
                description: String(localized: "Accédez rapidement à vos destinations préférées en fonction du temps, de votre position, et de vos habitudes"),
                color: .blue,
                icon: "link"
            ) {
                showShortcuts = true
            }
            
            CustomisationExplainationButton(
                title: String(localized: "Lignes préférées"),
                description: String(localized: "Indiquez les lignes que vous fréquentez le plus souvent pour les mettre en avant dans Lux. Si vous ne le faites pas, elles seront automatiquement ajoutées."),
                color: .green,
                icon: "chart.bar.fill"
            ) {
                showLineScore = true
            }
            
            CustomisationExplainationButton(
                title: String(localized: "Configurez LuxPass"),
                description: String(localized: "Ajoutez votre SwissPass à Lux"),
                color: .red,
                icon: "person.text.rectangle"
            ) {
                showLuxPass = true
            }
        }
    }
    
    private func pageHeader(icon: String, title: String, subtitle: Text) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(luxGradient)
                
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            subtitle
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var luxGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#FFD400"), Color(hex: "#FE7202")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func handleNextTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentPage < totalPages - 1 {
                currentPage += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                handleWelcomeCompletion()
            }
        }
    }
    
    private func handleWelcomeCompletion() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        settings.firstLaunch = false
        dismiss()
    }
}

// New button component without navigation destination
struct CustomisationExplainationButton: View {
    let title: String
    let description: String
    let color: Color
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 24, weight: .bold))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// https://stackoverflow.com/a/51241158
extension Bundle {
    public var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

#Preview {
    WelcomeView()
}
