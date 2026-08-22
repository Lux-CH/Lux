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
    @State private var categoryFilter: SFSymbolCategoryFilter = .all
    @State private var displayedSymbols: [SFSymbol] = []
    @State private var searchTask: Task<Void, Never>?
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
                scheduleSearch()
            }
            .onChange(of: categoryFilter) { _, _ in
                updateResults()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            updateResults()
        }
    }

    private func updateResults() {
        displayedSymbols = SymbolSearch.results(
            for: query,
            in: catalog.symbols,
            categoryFilter: categoryFilter
        )
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Voiture, maison, café...", text: $query)
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
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func categoryChip(title: String, icon: String, filter: SFSymbolCategoryFilter) -> some View {
        let isSelected = categoryFilter == filter

        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                categoryFilter = filter
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
            SFSymbolPickerGrid(
                selection: $selection,
                symbols: displayedSymbols,
                categoryFilter: .all,
                searchText: "",
                configuration: .init(edgePadding: 16)
            )
            .onChange(of: selection) { _, _ in
                dismiss()
            }
        }
    }
}
