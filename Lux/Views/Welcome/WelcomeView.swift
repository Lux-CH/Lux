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
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var showShortcuts = false
    @State private var showLineScore = false
    @State private var showLuxPass = false
    
    @State private var cardStyleIsSubtle: Bool = true

    private let totalPages = 5
    
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
                        locationPermissionPage
                            .tag(1)
                        transportGuidePage
                            .tag(2)
                        stopsPage
                            .tag(3)
                        finalPage
                            .tag(4)
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
            .onAppear {
                cardStyleIsSubtle = colorScheme == .light
            }
            .onChange(of: colorScheme) {
                cardStyleIsSubtle = colorScheme == .light
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
                Image(systemName: getNavigationIcon())
                    .font(.system(size: 16, weight: .medium))
                Text(getNavigationText())
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(getNavigationColor())
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .animation(.easeInOut(duration: 0.2), value: currentPage)
        .animation(.easeInOut(duration: 0.2), value: locationManager.authorizationStatus)
    }
    
    private func getNavigationIcon() -> String {
        if currentPage == 1 {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                return "location"
            case .denied, .restricted:
                return "gear"
            case .authorizedWhenInUse, .authorizedAlways:
                return "arrow.right"
            @unknown default:
                return "arrow.right"
            }
        } else if isLastPage {
            return "flag.checkered"
        } else {
            return "arrow.right"
        }
    }
    
    private func getNavigationText() -> String {
        if currentPage == 1 {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                return String(localized: "Autoriser")
            case .denied, .restricted:
                return String(localized: "Ouvrir Réglages")
            case .authorizedWhenInUse, .authorizedAlways:
                return String(localized: "Suivant")
            @unknown default:
                return String(localized: "Suivant")
            }
        } else if isLastPage {
            return "Commencer"
        } else {
            return "Suivant"
        }
    }
    
    private func getNavigationColor() -> Color {
        if currentPage == 1 {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                return .accentColor
            case .denied, .restricted:
                return .yellow
            case .authorizedWhenInUse, .authorizedAlways:
                return Color.primary
            @unknown default:
                return Color.primary
            }
        }
        return Color.primary
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
        ModernCard(style: cardStyleIsSubtle ? .subtle : .normal) {
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
                color: .yellow,
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
        VStack(spacing: 24) {
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
        ModernCard(style: cardStyleIsSubtle ? .subtle : .normal) {
            VStack(spacing: 20) {
                Text("Exemple d'arrêt")
                    .font(.headline)
                    .fontWeight(.semibold)
                stopPreviewCard
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 38,
                            bottomLeadingRadius: 24,
                            bottomTrailingRadius: 24,
                            topTrailingRadius: 38,
                            style: .continuous
                        )
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 38,
                            bottomLeadingRadius: 24,
                            bottomTrailingRadius: 24,
                            topTrailingRadius: 38,
                            style: .continuous
                        )
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                
                tipCard
            }
        }
    }
    
    private var stopPreviewCard: some View {
        StopView(stop:SearchResult(
            type: .stop,
            tokens: [],
            name: "Bel Air",
            id: "ch_Parent8587387",
            lat: 0.0,
            lon: 0.0,
            level: 0.0,
            areas: [],
            score: 0.0
        ), maxGroupsToShow: 3, fromStops: false, dontShowLastDivider: true, isLastStopOverall: true)
        .padding(.bottom, 7.5)
        .background(Color(.systemBackground).clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 38,
                bottomLeadingRadius: 24,
                bottomTrailingRadius: 24,
                topTrailingRadius: 38,
                style: .continuous
            ))
        )
    }
    
    private var tipCard: some View {
        ModernCard(style: cardStyleIsSubtle ? .normal : .subtle) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    
                    Text("Astuces")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                    
                    Spacer()
                }
                .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    tipItem(
                        icon: "hand.tap.fill",
                        text: Text("Cliquez sur \"\(Image(systemName: "signpost.right"))Bel Air\" pour plus de départs"),
                        color: .red
                    )
                    
                    tipItem(
                        icon: "hand.draw.fill",
                        text: Text("**Glissez horizontalement** pour changer de direction"),
                        color: .green
                    )
                    
                    tipItem(
                        icon: "info.circle.fill",
                        text: Text("Cliquez sur une ligne pour voir ses détails"),
                        color: .blue
                    )
                    tipItem(
                        icon: "square",
                        text: Text("Les quais sont indiqués dans les cases"),
                        color: .purple)
                }
            }
        }
    }

    private func tipItem(icon: String, text: Text, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)
            
            text
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var locationPermissionPage: some View {
        VStack(spacing: 36) {
            locationPageHeader
            locationCard
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var locationPageHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(getLocationIconColor().opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: getLocationIcon())
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(getLocationIconColor())
                }
                
                Text(getLocationTitle())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            
            Text(getLocationSubtitle())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 20)
    }
    
    private var locationCard: some View {
        ModernCard(style: cardStyleIsSubtle ? .subtle : .normal) {
            VStack(spacing: 24) {
                locationCardHeader
                locationFeatures
                locationStatusMessage
            }
        }
    }
    
    private var locationCardHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Localisation"))
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(String(localized: "Autorisez Lux à accéder à votre position"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var locationFeatures: some View {
        VStack(spacing: 16) {
            LocationFeatureItem(
                icon: "mappin.and.ellipse",
                title: String(localized: "Arrêts à proximité"),
                description: String(localized: "Trouvez rapidement les arrêts les plus proches"),
                color: .blue
            )
            
            Divider().opacity(0.3)
            
            LocationFeatureItem(
                icon: "arrow.triangle.turn.up.right.diamond",
                title: String(localized: "Itinéraires"),
                description: String(localized: "Obtenez les meilleurs trajets depuis votre position"),
                color: .green
            )
            
            Divider().opacity(0.3)
            
            LocationFeatureItem(
                icon: "clock.arrow.circlepath",
                title: String(localized: "Suggestions en temps réel"),
                description: String(localized: "Recevez des informations basées sur votre position"),
                color: .indigo
            )
        }
    }
    
    @ViewBuilder
    private var locationStatusMessage: some View {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            EmptyView()
        case .denied, .restricted:
            ModernCard(style: cardStyleIsSubtle ? .normal : .subtle) {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(String(localized: "Localisation désactivée"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    
                    Text(String(localized: "Vous pouvez activer la localisation dans les réglages de votre appareil pour profiter pleinement de Lux."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        case .authorizedWhenInUse, .authorizedAlways:
            ModernCard(style: cardStyleIsSubtle ? .normal : .subtle) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))
                    
                    Text(String(localized: "Localisation activée"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
            }
        @unknown default:
            EmptyView()
        }
    }
    
    private func getLocationIcon() -> String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "location"
        case .denied, .restricted:
            return "location.slash"
        case .authorizedWhenInUse, .authorizedAlways:
            return "location.fill"
        @unknown default:
            return "location"
        }
    }
    
    private func getLocationIconColor() -> Color {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return .accentColor
        case .denied, .restricted:
            return .orange
        case .authorizedWhenInUse, .authorizedAlways:
            return .green
        @unknown default:
            return .accentColor
        }
    }
    
    private func getLocationTitle() -> String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return String(localized: "Autoriser la localisation")
        case .denied, .restricted:
            return String(localized: "Localisation désactivée")
        case .authorizedWhenInUse, .authorizedAlways:
            return String(localized: "Localisation activée")
        @unknown default:
            return String(localized: "Autoriser la localisation")
        }
    }
    
    private func getLocationSubtitle() -> String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return String(localized: "Lux utilise votre position pour vous proposer les arrêts à proximité et les meilleurs itinéraires.")
        case .denied, .restricted:
            return String(localized: "Vous pouvez continuer à utiliser Lux, mais certaines fonctionnalités seront limitées.")
        case .authorizedWhenInUse, .authorizedAlways:
            return String(localized: "Parfait ! Vous pouvez maintenant profiter pleinement de toutes les fonctionnalités de Lux.")
        @unknown default:
            return String(localized: "Lux utilise votre position pour vous proposer les arrêts à proximité et les meilleurs itinéraires.")
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
        ModernCard(style: cardStyleIsSubtle ? .subtle : .normal) {
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
                    .opacity(icon == "signpost.right" ? 0.0 : 1.0)
                
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(icon == "signpost.right" ? AnyShapeStyle(luxGradient) : AnyShapeStyle(Color.primary))
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
        
        if currentPage == 1 {
            switch locationManager.authorizationStatus {
            case .notDetermined:
                locationManager.requestLoc()
                return
            case .denied, .restricted:
                openAppSettings()
                return
            default:
                break
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentPage < totalPages - 1 {
                currentPage += 1
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                handleWelcomeCompletion()
            }
        }
    }
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func handleWelcomeCompletion() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
        settings.firstLaunch = false
        dismiss()
    }
}

struct LocationFeatureItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

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
