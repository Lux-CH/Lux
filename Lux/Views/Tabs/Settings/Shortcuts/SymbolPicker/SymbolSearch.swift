//
//  SymbolSearch.swift
//  Lux
//
//  Created by Constantin Clerc on 23.08.2026.
//

import Foundation
import SFSymbols

enum SymbolSearch {
    static func results(
        for query: String,
        in symbols: [SFSymbol],
        categoryFilter: SFSymbolCategoryFilter = .all
    ) -> [SFSymbol] {
        let folded = fold(query)
        let isExactSymbolName = symbols.contains { $0.name == folded }
        let terms = searchTerms(for: query, preferringRawQuery: isExactSymbolName)
        guard !terms.isEmpty else {
            return symbols.filter { categoryFilter.matches($0) }
        }
        var seen: Set<String> = []
        var results: [SFSymbol] = []
        for term in terms {
            for symbol in symbols.search(matching: term, categoryFilter: categoryFilter)
            where seen.insert(symbol.name).inserted {
                results.append(symbol)
            }
        }
        return results
    }

    static func searchTerms(for query: String, preferringRawQuery: Bool = false) -> [String] {
        let folded = fold(query)
        guard !folded.isEmpty else { return [] }

        var terms: [String] = []
        var seen: Set<String> = []
        func add(_ term: String) {
            guard !term.isEmpty, seen.insert(term).inserted else { return }
            terms.append(term)
        }

        let words = folded
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !stopWords.contains($0) }

        let isKnownInLexicon = words.contains { isInLexicon($0) }

        if preferringRawQuery || !isKnownInLexicon {
            add(folded)
        }

        guard !words.isEmpty else {
            add(folded)
            return terms
        }

        if words.count > 1 {
            let phrase = words.compactMap { translations(for: $0).first }.joined(separator: " ")
            add(phrase)
        }

        for word in words {
            for translation in translations(for: word) {
                add(translation)
            }
        }

        add(folded)
        return terms
    }

    static func fold(_ text: String) -> String {
        text.replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "Œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "Æ", with: "ae")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isInLexicon(_ word: String) -> Bool {
        if SymbolLexicon.translations[word] != nil {
            return true
        }
        guard word.count > 3, word.hasSuffix("s") || word.hasSuffix("x") else { return false }
        return SymbolLexicon.translations[String(word.dropLast())] != nil
    }

    private static func translations(for word: String) -> [String] {
        if let match = SymbolLexicon.translations[word] {
            return match
        }
        if word.count > 3, word.hasSuffix("s") || word.hasSuffix("x") {
            let singular = String(word.dropLast())
            if let match = SymbolLexicon.translations[singular] {
                return match
            }
        }
        return [word]
    }

    private static let stopWords: Set<String> = [
        "a", "au", "aux", "avec", "ce", "cet", "cette", "d", "dans", "de", "des",
        "du", "en", "et", "l", "la", "le", "les", "ma", "mes", "mon", "n", "ou",
        "par", "pour", "sa", "ses", "sur", "un", "une", "vers"
    ]
}

private extension SFSymbolCategoryFilter {
    func matches(_ symbol: SFSymbol) -> Bool {
        switch self {
        case .all: true
        case .category(let category): symbol.categories.contains(category.key)
        }
    }
}
