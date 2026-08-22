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
    @Published private(set) var isLoading = true

    private static var cached: (symbols: [SFSymbol], categories: [SFSymbolCategory])?

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
        let categories = Self.usableCategories(from: catalog.categories, containing: symbols)
        let result = (symbols: symbols, categories: categories)
        Self.cached = result
        apply(result)
    }

    private func apply(_ result: (symbols: [SFSymbol], categories: [SFSymbolCategory])) {
        symbols = result.symbols
        categories = result.categories
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
