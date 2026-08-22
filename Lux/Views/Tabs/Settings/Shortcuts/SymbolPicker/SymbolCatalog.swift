//
//  SymbolCatalog.swift
//  Lux
//
//  Created by Constantin Clerc on 23.08.2026.
//

import Foundation
import SFSymbols

@MainActor
final class SymbolCatalog: ObservableObject {
    @Published private(set) var symbols: [SFSymbol] = []
    @Published private(set) var categories: [SFSymbolCategory] = []
    @Published private(set) var recommended: [SFSymbol] = []
    @Published private(set) var isLoading = true

    private static var cached: Loaded?

    struct Loaded {
        let symbols: [SFSymbol]
        let categories: [SFSymbolCategory]
        let recommended: [SFSymbol]
    }

    func load() async {
        if let cached = Self.cached {
            apply(cached)
            return
        }
        guard let catalog = try? await SFSymbols() else {
            isLoading = false
            return
        }
        let restricted = Self.restrictedSymbolNames()
        let symbols = catalog.symbols.filter { symbol in
            !restricted.contains(symbol.name) && !Self.isScriptVariant(symbol.name)
        }
        let result = Loaded(
            symbols: symbols,
            categories: Self.usableCategories(from: catalog.categories, containing: symbols),
            recommended: Self.recommendedSymbols(from: symbols)
        )
        Self.cached = result
        apply(result)
    }

    private func apply(_ result: Loaded) {
        symbols = result.symbols
        categories = result.categories
        recommended = result.recommended
        isLoading = false
    }
}

private extension SymbolCatalog {
    static let excludedCategoryKeys: Set<String> = ["variable", "multicolor", "whatsnew"]

    static let scriptVariantComponents: Set<String> = [
        "ar", "he", "hi", "ja", "ko", "th", "zh",
        "bn", "gu", "kn", "ml", "mni", "mr", "or", "pa", "sat", "si", "ta", "te",
        "rtl"
    ]

    static func isScriptVariant(_ name: String) -> Bool {
        name.split(separator: ".")
            .dropFirst()
            .contains { scriptVariantComponents.contains(String($0)) }
    }

    static func restrictedSymbolNames() -> Set<String> {
        guard let bundle = Bundle(identifier: "com.apple.CoreGlyphs"),
              let path = bundle.path(forResource: "symbol_restrictions", ofType: "strings"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let restrictions = try? PropertyListSerialization.propertyList(
                  from: data,
                  format: nil
              ) as? [String: String]
        else {
            return []
        }
        return Set(restrictions.keys)
    }

    static func recommendedSymbols(from symbols: [SFSymbol]) -> [SFSymbol] {
        var byName: [String: SFSymbol] = [:]
        byName.reserveCapacity(symbols.count)
        for symbol in symbols {
            byName[symbol.name] = symbol
        }
        return recommendedNames.compactMap { byName[$0] }
    }

    static let recommendedNames: [String] = [
        "tram", "bus", "train.side.front.car", "car", "bicycle", "scooter", "airplane",
        "ferry", "cablecar", "figure.walk", "fuelpump", "parkingsign", "map", "mappin",
        "location", "signpost.right", "suitcase",

        "house", "building.2", "building.columns", "briefcase", "graduationcap",
        "books.vertical", "storefront", "cart", "bag", "fork.knife", "cup.and.saucer",
        "wineglass", "bed.double", "cross.case", "stethoscope", "pills", "scissors",
        "theatermasks", "film",

        "person", "person.2", "person.3", "figure.2.and.child.holdinghands",
        "figure.child", "heart", "pawprint",

        "figure.run", "figure.strengthtraining.traditional", "dumbbell",
        "figure.pool.swim", "figure.hiking", "figure.yoga", "figure.soccer", "sportscourt",

        "clock", "calendar", "alarm", "ticket", "creditcard", "gift", "birthday.cake",
        "camera", "music.note", "gamecontroller", "book", "doc.text", "envelope", "phone",
        "wifi", "key", "lock", "star", "flag", "tag", "bell", "bolt", "basket",

        "flame", "drop", "leaf", "tree", "sun.max", "moon.stars", "snowflake",
        "beach.umbrella", "mountain.2", "water.waves", "globe"
    ]

    static func usableCategories(
        from categories: [SFSymbolCategory],
        containing symbols: [SFSymbol]
    ) -> [SFSymbolCategory] {
        var populatedKeys: Set<String> = []
        for symbol in symbols {
            populatedKeys.formUnion(symbol.categories)
        }
        return categories.displayable.filter { category in
            !excludedCategoryKeys.contains(category.key) && populatedKeys.contains(category.key)
        }
    }
}

extension SFSymbolCategory {
    var localizedName: String {
        switch key {
        case "communication": String(localized: "Communication")
        case "weather": String(localized: "Météo")
        case "maps": String(localized: "Cartes")
        case "objectsandtools": String(localized: "Objets et outils")
        case "devices": String(localized: "Appareils")
        case "cameraandphotos": String(localized: "Photo et vidéo")
        case "gaming": String(localized: "Jeux")
        case "connectivity": String(localized: "Connectivité")
        case "transportation": String(localized: "Transports")
        case "automotive": String(localized: "Automobile")
        case "accessibility": String(localized: "Accessibilité")
        case "privacyandsecurity": String(localized: "Confidentialité")
        case "human": String(localized: "Personnes")
        case "home": String(localized: "Maison")
        case "fitness": String(localized: "Sport")
        case "nature": String(localized: "Nature")
        case "editing": String(localized: "Retouche")
        case "textformatting": String(localized: "Mise en forme")
        case "media": String(localized: "Multimédia")
        case "keyboard": String(localized: "Clavier")
        case "commerce": String(localized: "Commerce")
        case "time": String(localized: "Temps")
        case "health": String(localized: "Santé")
        case "shapes": String(localized: "Formes")
        case "arrows": String(localized: "Flèches")
        case "indices": String(localized: "Lettres et chiffres")
        case "math": String(localized: "Maths")
        case "draw": String(localized: "Dessin")
        default: key.capitalized
        }
    }
}
