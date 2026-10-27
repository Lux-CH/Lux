//
//  LuxApp.swift
//  Lux
//
//  Created by Constantin Clerc on 29.03.2025.
//

import SwiftUI
import CoreLocation
import LuxCom

final class LuxAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        OnboardLiveActivityController.endAll()
        if #available(iOS 17.0, *) {
            CLBackgroundActivitySession().invalidate()
        }
        DepartureAlertPlanner.register()
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        MainActor.assumeIsolated { OnboardSession.active?.stop() }
        OnboardLiveActivityController.endAllBeforeTermination()
    }
}

@main
struct LuxApp: App {
    @UIApplicationDelegateAdaptor(LuxAppDelegate.self) private var appDelegate
    @StateObject private var locationManager = LocationManager()
    @StateObject private var shortcutManager = ShortcutManager()
    @StateObject private var disruptionManager = DisruptionManager()
    @StateObject private var offlineManager = OfflineManager.shared

    @State private var pendingURL: URL?
    @ObservedObject var settings = Settings.shared
    
    var body: some Scene {
        WindowGroup {
            MainNavigationView()
                .preferredColorScheme(getColorScheme())
                .environmentObject(locationManager)
                .environmentObject(shortcutManager)
                .environmentObject(disruptionManager)
                .environmentObject(offlineManager)
                .luxAccentTint()
                .onAppear {
                    if ((settings.appLaunchCount % 15) == 0) {
                        Task.detached(priority: .background) {
                            await CacheCleaner.performCleanup()
                        }
                    }
                    settings.appLaunchCount += 1
                    DepartureAlertPlanner.shared.refresh()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    DepartureAlertPlanner.shared.refresh()
                }
                .onOpenURL { url in
                    Task {
                        await handleIncomingURL(url)
                    }
                }
                .fullScreenCover(isPresented: $settings.firstLaunch) {
                    WelcomeView()
                        .environmentObject(locationManager)
                        .environmentObject(shortcutManager)
                        .environmentObject(disruptionManager)
                }
        }
    }
    
    @MainActor
    private func handleIncomingURL(_ url: URL) async {
        if url.scheme == "lux" && url.host == "onboard" { return }
        let result = await URLHandler.process(url)
        
        switch result {
        case .confirmationRequired(let url):
            pendingURL = url
            presentConfirmation(for: url)
            
        case .stopPlace(let name, let stopId):
            presentLinked(TripsSearchView(
                initialSearchResult: SearchResult(type: .stop, tokens: [], name: name, id: stopId, lat: 0.0, lon: 0.0, areas: [], score: 0.0),
                initialTargetField: .to
            ))
            
        case .stopDetail(let stopId, let name):
            presentLinked(stopView(stopId: stopId, name: name))
            
        case .itinerary(let itinerary):
            presentLinked(ItineraryView(itinerary: itinerary, liveShare: nil))
            
        case .liveItinerary:
            break
            
        case .error(let error):
            presentError(error.localizedDescription)
        }
    }
    
    @MainActor
    private func handleConfirmedItinerary(_ url: URL) async {
        let result = await URLHandler.handleConfirmedItinerary(url)
        
        switch result {
        case .itinerary(let itinerary):
            presentLinked(ItineraryView(itinerary: itinerary, liveShare: nil))
            
        case .liveItinerary(let itinerary, let link):
            presentLinked(ItineraryView(itinerary: itinerary, liveShare: link))
            
        case .error(let error):
            presentError(error.localizedDescription)
            
        default:
            presentError(String(localized: "Une erreur est survenue."))
        }
        
        pendingURL = nil
    }
    
    @MainActor
    private func presentConfirmation(for url: URL) {
        let alert = UIAlertController(
            title: String(localized: "Êtes-vous sûr de vouloir ouvrir cet itinéraire ?"),
            message: String(localized: "Cet itinéraire vous a été partagé. Assurez-vous qu'il provient d'une source fiable."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Annuler"), style: .cancel) { _ in
            pendingURL = nil
        })
        alert.addAction(UIAlertAction(title: String(localized: "Ouvrir"), style: .default) { _ in
            Task { await handleConfirmedItinerary(url) }
        })
        presentOnTop(alert)
    }
    
    @MainActor
    private func presentError(_ message: String) {
        let alert = UIAlertController(
            title: String(localized: "L'itinéraire n'a pas pu être ouvert."),
            message: message.isEmpty ? String(localized: "Une erreur est survenue lors de son ouverture. Il est possible que le lien ait expiré.") : message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
        presentOnTop(alert)
    }
    
    @MainActor
    private func presentLinked<Content: View>(_ content: Content) {
        let colorScheme = getColorScheme()
        let host = UIHostingController(rootView: content
            .preferredColorScheme(colorScheme)
            .environmentObject(locationManager)
            .environmentObject(shortcutManager)
            .environmentObject(disruptionManager)
            .environmentObject(offlineManager)
            .luxAccentTint())
        host.modalPresentationStyle = .fullScreen
        host.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : colorScheme == .light ? .light : .unspecified
        presentOnTop(host)
    }
    
    @MainActor
    private func presentOnTop(_ controller: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        top.present(controller, animated: true)
    }
    
    private func getColorScheme() -> ColorScheme? {
        if settings.autoColorScheme {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: Date())
            
            if hour >= 20 || hour < 6 {
                return .dark
            } else {
                return .light
            }
        }
        if settings.customScheme {
            if settings.customSchemeSelection == "dark" {
                return .dark
            } else {
                return .light
            }
        } else {
            return nil
        }
    }
    
    private func stopView(stopId: String, name: String) -> some View {
        ItineraryStopDetailView(stop: Place(
            name: name,
            stopId: stopId,
            lat: 0.0,
            lon: 0.0,
            level: 0,
            arrival: nil,
            departure: nil,
            scheduledArrival: nil,
            scheduledDeparture: nil,
            scheduledTrack: nil,
            track: nil,
            vertexType: .transit))
    }
}
