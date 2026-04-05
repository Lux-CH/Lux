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
    private let resultCardCornerRadius: CGFloat = 16
    private var resultCardTint: Color {
        colorScheme == .dark ? Color(.systemBackground).opacity(0.8) : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Résultats")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 22)
                .padding(.bottom, 8)
            
            ScrollView {
                GlassEffectGroup(spacing: 12) {
                    VStack(spacing: 12) {
                        ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
                            Button(action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    viewModel.selectLocation(result)
                                    HapticFeedback.lightImpact()
                                }
                            }) {
                                SearchResultRow(result: result)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                    .adaptable(
                                        ios26: .glassButtonTintedIn(
                                            AnyShape(RoundedRectangle(cornerRadius: resultCardCornerRadius, style: .continuous)),
                                            resultCardTint
                                        ),
                                        fallback: {
                                            $0.background(
                                                RoundedRectangle(cornerRadius: resultCardCornerRadius, style: .continuous)
                                                    .fill(colorScheme == .dark ?
                                                          Color(.systemBackground).opacity(0.8) :
                                                          Color(.systemBackground))
                                                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                                            )
                                        }
                                    )
                                    .opacity(appearAnimation ? 1 : 0)
                                    .offset(y: appearAnimation ? 0 : 10)
                                    .animation(
                                        .spring(response: 0.3, dampingFraction: 0.75)
                                        .delay(Double(index) * 0.05),
                                        value: appearAnimation
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(.bottom, 16)
            }
            .scrollClipDisabled()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    appearAnimation = true
                }
            }
        }
        .onDisappear {
            appearAnimation = false
        }
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
    @State private var isHovering = false
    private let resultCardCornerRadius: CGFloat = 16
    private var resultCardTint: Color {
        colorScheme == .dark ? Color(.systemBackground).opacity(0.8) : Color(.systemBackground)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Localisation")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 22)
                .padding(.bottom, 12)
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    viewModel.selectCurrentPosition()
                    HapticFeedback.lightImpact()
                }
            }) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.accentColor)
                            .scaleEffect(isHovering ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                    }
                    
                    Text("Position Actuelle")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(isHovering ? 1 : 0.6)
                        .offset(x: isHovering ? 4 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isHovering)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .adaptable(
                    ios26: .glassButtonTintedIn(
                        AnyShape(RoundedRectangle(cornerRadius: resultCardCornerRadius, style: .continuous)),
                        resultCardTint
                    ),
                    fallback: {
                        $0.background(
                            RoundedRectangle(cornerRadius: resultCardCornerRadius, style: .continuous)
                                .fill(colorScheme == .dark ?
                                      Color(.systemBackground).opacity(0.8) :
                                      Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                        )
                    }
                )
                .padding(.horizontal)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .buttonStyle(ScaleButtonStyle())
            
            Divider()
                .padding(.vertical, 16)
                .padding(.horizontal)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
