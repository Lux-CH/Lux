//
//  SymbolPickerSheet.swift
//  Lux
//
//  Created by Constantin Clerc on 23.08.2026.
//

import SwiftUI
import SFSymbols

struct SymbolPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = SymbolCatalog()
    @ObservedObject private var accentColorManager = AccentColorManager.shared

    @Binding var selection: String

    @State private var query = ""
    @State private var filter: SymbolFilter = .recommended
    @State private var displayedSymbols: [SFSymbol] = []
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if !catalog.categories.isEmpty && query.isEmpty {
                    categoryStrip
                }

                Divider()

                content
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Choisir un symbole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                }
            }
            .task {
                await catalog.load()
                updateResults()
            }
            .onChange(of: query) { _, _ in
                updateResults()
            }
            .onChange(of: filter) { _, _ in
                updateResults()
            }
        }
    }

    private func updateResults() {
        let isSearching = !SymbolSearch.fold(query).isEmpty

        if !isSearching, filter == .recommended {
            displayedSymbols = catalog.recommended
            return
        }
        displayedSymbols = SymbolSearch.results(
            for: query,
            in: catalog.symbols,
            categoryFilter: isSearching ? .all : filter.categoryFilter
        )
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Travail, maison, école...", text: $query)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
                .submitLabel(.search)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !catalog.recommended.isEmpty {
                    categoryChip(
                        title: String(localized: "Suggestions"),
                        icon: "sparkles",
                        filter: .recommended
                    )
                }

                categoryChip(title: String(localized: "Tous"), icon: "square.grid.2x2", filter: .all)

                ForEach(catalog.categories) { category in
                    categoryChip(
                        title: category.localizedName,
                        icon: category.icon.name,
                        filter: .category(category)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func categoryChip(title: String, icon: String, filter: SymbolFilter) -> some View {
        let isSelected = self.filter == filter

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                self.filter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected
                          ? accentColorManager.selectedAccentColor.opacity(0.15)
                          : Color(.tertiarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? accentColorManager.selectedAccentColor : .primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        if catalog.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if displayedSymbols.isEmpty {
            Spacer()
            ContentUnavailableView(
                String(localized: "Aucun symbole"),
                systemImage: "magnifyingglass",
                description: Text("Aucun résultat pour « \(query) »")
            )
            Spacer()
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(displayedSymbols) { symbol in
                        Button {
                            select(symbol.name)
                        } label: {
                            SymbolTile(
                                name: symbol.name,
                                isSelected: symbol.name == selection,
                                tint: accentColorManager.selectedAccentColor
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
                .background(alignment: .top) {
                    Color.clear.frame(height: 1).id("top")
                }
            }
            .onChange(of: displayedSymbols) { _, _ in
                proxy.scrollTo("top", anchor: .top)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 57), spacing: 14)]
    }

    private func select(_ name: String) {
        selection = name
        dismiss()
    }
}

enum SymbolFilter: Hashable {
    case recommended
    case all
    case category(SFSymbolCategory)

    var categoryFilter: SFSymbolCategoryFilter {
        switch self {
        case .recommended, .all: .all
        case .category(let category): .category(category)
        }
    }
}

private struct SymbolTile: View {
    let name: String
    let isSelected: Bool
    let tint: Color

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .frame(height: 45)
            .overlay {
                Image(systemName: name)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.primary))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.separator),
                        lineWidth: isSelected ? 2 : 1 / displayScale
                    )
            }
    }
}
