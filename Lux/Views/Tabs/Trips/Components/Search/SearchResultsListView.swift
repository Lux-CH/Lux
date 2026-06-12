//
//  SearchResultsListView.swift
//  Lux
//
//  Created by Constantin Clerc on 26.07.2025.
//

import SwiftUI

struct SearchResultsListView: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var appearAnimation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Résultats")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                viewModel.selectLocation(result)
                                HapticFeedback.lightImpact()
                            }
                        }) {
                            SearchResultRow(result: result)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .opacity(appearAnimation ? 1 : 0)
                        .offset(y: appearAnimation ? 0 : 8)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.8).delay(Double(index) * 0.04),
                            value: appearAnimation
                        )

                        if index < viewModel.searchResults.count - 1 {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark
                            ? Color(.tertiarySystemBackground)
                            : Color(.secondarySystemBackground))
                        .shadow(
                            color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.1),
                            radius: 12, x: 0, y: 4
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06), lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .scrollClipDisabled()
            .mask(
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black, Color.clear]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 28)
                }
            )
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { appearAnimation = true }
            }
        }
        .onDisappear { appearAnimation = false }
    }
}

struct EmptySearchView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 40)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
            
            Text("Recherchez un lieu ou une adresse")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
        
        Spacer()
    }
}


struct SearchResultsContent: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if (viewModel.activeSearchField != .none && viewModel.fromQuery.isEmpty && viewModel.toQuery.isEmpty) && viewModel.isCurrentPositionAvailable() {
                CurrentLocationOption(viewModel: viewModel)
            } else if viewModel.showMinCharactersMessage {
                MinCharactersView()
            } else if !viewModel.searchResults.isEmpty {
                SearchResultsListView(viewModel: viewModel)
            } else {
                EmptySearchView()
            }
        }
    }
}

struct LoadingView: View {
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .frame(width: 80, height: 80)
                
            Text("Recherche d'itinéraires...")
                .font(.headline)
                .foregroundColor(.secondary)
                .opacity(pulseAnimation ? 0.7 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                .onAppear {
                    pulseAnimation = true
                }
        }
        .padding(.top, 40)
        .transition(.opacity)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    @State private var isAnimatingIcon = false
    @Environment(\.colorScheme) private var colorScheme
    
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 46))
                .foregroundColor(.orange)
                .symbolEffect(.pulse, options: .repeating.speed(0.7), value: isAnimatingIcon)
                .onAppear {
                    isAnimatingIcon = true
                }
                
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("Il est possible que le serveur soit actuellement indisponible.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Réessayer") {
                HapticFeedback.mediumImpact()
                retryAction()
            }
            .padding()
            .background(
                colorScheme == .dark
                ? Color(.tertiarySystemBackground)
                : Color(.systemBackground)
            )
            .clipShape(Capsule(style: .continuous))
            .padding(.top, 10)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct NoResultsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 46))
                .foregroundColor(.secondary)
                .symbolEffect(.bounce.up, options: .repeating.speed(0.5), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
                
            Text("Aucun itinéraire trouvé")
                .font(.headline)
                .foregroundColor(.secondary)
                
            Text("Essayez de modifier vos critères de recherche, vos options ou l'heure de départ.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

struct MinCharactersView: View {
    @State private var isAnimatingText = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "character.cursor.ibeam")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
                .padding(.top, 40)
            
            Text("Entrez au moins 3 caractères pour rechercher")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .opacity(isAnimatingText ? 1 : 0.7)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimatingText)
                .onAppear {
                    isAnimatingText = true
                }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
        
        Spacer()
    }
}



struct CurrentLocationOption: View {
    @ObservedObject var viewModel: TripsSearchViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Localisation")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    viewModel.selectCurrentPosition()
                    HapticFeedback.lightImpact()
                }
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                            .frame(width: 38, height: 38)
                        Image(systemName: "location.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.accentColor)
                    }

                    Text("Position Actuelle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark
                            ? Color(.tertiarySystemBackground)
                            : Color(.systemBackground))
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.07),
                    radius: 14, x: 0, y: 4
                )
                .padding(.horizontal, 16)
            }
            .buttonStyle(ScaleButtonStyle())

            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
