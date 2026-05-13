//
//  ItineraryActionTips.swift
//  Lux
//
//  Created by GitHub Copilot on 13.05.2026.
//

import SwiftUI
import TipKit

enum ItineraryTipState {
    @Parameter static var didUseShareAction: Bool = false
    @Parameter static var didUseSaveAction: Bool = false
    @Parameter static var didUseTripSelection: Bool = false
}

struct ItineraryShareTip: Tip {
    var title: Text {
        Text("Partager l'itinéraire")
    }

    var message: Text? {
        Text("Ce bouton permet de partager votre trajet à d'autres via un lien.")
    }

    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }

    var rules: [Rule] {
        #Rule(ItineraryTipState.$didUseShareAction) {
            $0 == false
        }
    }

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }
}

struct ItinerarySaveTip: Tip {
    var title: Text {
        Text("Sauvegarder le trajet")
    }

    var message: Text? {
        Text("Ce bouton enregistre l'itinéraire dans l'app pour vous le proposer le moment venu.")
    }

    var image: Image? {
        Image(systemName: "bookmark")
    }

    var rules: [Rule] {
        #Rule(ItineraryTipState.$didUseSaveAction) {
            $0 == false
        }
    }

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }
}

struct ItineraryClockTip: Tip {
    var title: Text {
        Text("Autres départs")
    }

    var message: Text? {
        Text("L'icône horloge vous montre les autres horaires à venir pour cette ligne. Cliquez sur un horaire pour voir plus de détails.")
    }

    var image: Image? {
        Image(systemName: "clock")
    }

    var rules: [Rule] {
        #Rule(ItineraryTipState.$didUseTripSelection) {
            $0 == false
        }
    }

    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }
}

extension View {
    @ViewBuilder
    func itineraryTip<T: Tip>(_ tip: T, enabled: Bool, arrowEdge: Edge) -> some View {
        if #available(iOS 26.0, *), enabled {
            self.popoverTip(tip, arrowEdge: arrowEdge)
        } else {
            self
        }
    }
}
