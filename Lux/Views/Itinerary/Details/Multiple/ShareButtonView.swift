//
//  ShareButtonView.swift
//  Lux
//
//  Created by Constantin Clerc on 03.08.2025.
//
//  https://www.hackingwithswift.com/quick-start/swiftui/how-to-convert-a-swiftui-view-to-an-image

import SwiftUI
import LuxCom

struct ShareButtonView: View {
    let itinerary: Itinerary
    let itineraarySharer: ItinerarySharer
    let compact: Bool
    let showCompactSaveAction: Bool
    
    @State private var showingShareDialog = false
    @State private var renderedUIImage: UIImage?
    @State private var isUploading = false
    @State private var isRenderingPreviewImage = false
    @State private var isSavingItinerary = false
    @State private var uploadedURL: String?
    @State private var showingShareSheet = false
    @State private var showingImageShareSheet = false
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var showCheckmark = false
    @State private var isItinerarySavedLocally = false
    @State private var didSaveInCurrentSession = false
    @State private var hasResolvedSavedState = false
    @State private var savedStateTask: Task<Void, Never>?
    @Environment(\.displayScale) var displayScale
    
    init(
        itinerary: Itinerary,
        itineraarySharer: ItinerarySharer,
        compact: Bool,
        showCompactSaveAction: Bool = true
    ) {
        self.itinerary = itinerary
        self.itineraarySharer = itineraarySharer
        self.compact = compact
        self.showCompactSaveAction = showCompactSaveAction
    }
    
    var body: some View {
        Group {
            if compact {
                VStack(spacing: 10) {
                    Menu {
                        Button {
                            uploadItinerary()
                        } label: {
                            Label("Partager l'entiereté", systemImage: "link")
                        }
                        
                        Button {
                            shareRenderedPreviewImage()
                        } label: {
                            Label(
                                isRenderingPreviewImage ? "Préparation de l'image..." : "Partager l'aperçu en tant qu'image",
                                systemImage: "photo"
                            )
                        }
                        .disabled(isRenderingPreviewImage)
                    } label: {
                        floatingButtonContainer {
                            if isUploading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                                    .offset(y: -1)
                            }
                        }
                    }
                    .disabled(isUploading || isSavingItinerary)
                    
                    if showCompactSaveAction && shouldShowCompactSaveButton {
                        Button {
                            saveItinerary()
                        } label: {
                            floatingButtonContainer {
                                ZStack {
                                    if isSavingItinerary {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .transition(.opacity)
                                    } else {
                                        Image(systemName: compactSaveSymbolName)
                                            .font(.headline)
                                            .foregroundColor(compactSaveSymbolColor)
                                            .offset(y: -1)
                                            .contentTransition(.symbolEffect(.replace))
                                            .transition(.opacity)
                                            .id(compactSaveSymbolName)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: isSavingItinerary)
                                .animation(.easeInOut(duration: 0.2), value: compactSaveSymbolName)
                            }
                        }
                        .disabled(isUploading || isSavingItinerary || didSaveInCurrentSession)
                        .accessibilityLabel("Sauvegarder l'itinéraire")
                        .transition(.opacity)
                    }
                }
            } else {
                Button(action: {
                    showingShareDialog = true
                }) {
                    HStack {
                        if isUploading || isSavingItinerary {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isUploading ? "Partage..." : isSavingItinerary ? "Enregistrement..." : "Partager")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    )
                }
                .disabled(isUploading || isSavingItinerary)
                .confirmationDialog("Partager l'itinéraire", isPresented: $showingShareDialog, titleVisibility: .visible) {
                    Button("Partager l'entiereté") {
                        uploadItinerary()
                    }
                    
                    Button(isRenderingPreviewImage ? "Préparation de l'image..." : "Partager l'aperçu en tant qu'image") {
                        shareRenderedPreviewImage()
                    }
                    .disabled(isRenderingPreviewImage)
                    
                    Button("Sauvegarder l'itinéraire") {
                        saveItinerary()
                    }
                    
                    Button("Annuler", role: .cancel) { }
                } message: {
                    Text("Choisissez comment vous souhaitez partager cet itinéraire.\nLe partage de l'ensemble de l'itinéraire requiert que son receveur ait l'app.")
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = uploadedURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showingImageShareSheet) {
            if let uiImage = renderedUIImage {
                ShareSheet(items: [uiImage])
            }
        }
        .alert("Sauvegarder l'itinéraire", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveAlertMessage)
        }
        .onAppear {
            refreshSavedState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .savedItinerariesDidChange)) { _ in
            refreshSavedState()
        }
        .onDisappear {
            savedStateTask?.cancel()
            savedStateTask = nil
        }
    }
    
    private var shouldShowCompactSaveButton: Bool {
        if isSavingItinerary || showCheckmark || didSaveInCurrentSession {
            return true
        }
        
        guard hasResolvedSavedState else {
            return false
        }
        
        return !isItinerarySavedLocally
    }
    
    private var compactSaveSymbolName: String {
        if showCheckmark {
            return "checkmark"
        }
        
        if didSaveInCurrentSession && isItinerarySavedLocally {
            return "bookmark.fill"
        }
        
        return "bookmark"
    }
    
    private var compactSaveSymbolColor: Color {
        if showCheckmark || (didSaveInCurrentSession && isItinerarySavedLocally) {
            return .green
        }
        
        return .accentColor
    }
    
    @ViewBuilder
    private func floatingButtonContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 45, height: 45)
            .clipShape(Circle())
            .adaptable(ios26: .glassButton, fallback: {
                $0.background(.ultraThickMaterial).overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )

            })
            .shadow(radius: 2)
    }
    
    private func uploadItinerary() {
        isUploading = true
        showingShareDialog = false
        
        Task {
            let result = await itineraarySharer.uploadItinerary(itinerary, expiresInHours: nil)
            
            await MainActor.run {
                isUploading = false
                
                switch result {
                case .success(let identifier):
                    uploadedURL = "https://lux.cclerc.ch/share.html#\(identifier)"
                    showingShareSheet = true
                case .failure(let error):
                    print("upload failed !! \(error)")
                }
            }
        }
    }
    
    private func shareRenderedPreviewImage() {
        guard !isRenderingPreviewImage else {
            return
        }
        
        showingShareDialog = false
        
        if renderedUIImage != nil {
            showingImageShareSheet = true
            return
        }
        
        isRenderingPreviewImage = true
        
        Task(priority: .userInitiated) {
            await MainActor.run {
                renderImage()
                isRenderingPreviewImage = false
                
                if renderedUIImage != nil {
                    showingImageShareSheet = true
                } else {
                    saveAlertMessage = String(localized: "Impossible de générer l'aperçu de l'itinéraire.")
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func saveItinerary() {
        let localSaveResult = SavedItineraryStorage.shared.save(itinerary)
        let calendarManager = CalendarManager(itinerarySharer: itineraarySharer)
        isSavingItinerary = true
        showingShareDialog = false
        
        Task {
            var calendarResult: Result<Void, CalendarError>?

            if calendarManager.authorizationStatus == .fullAccess {
                calendarResult = await calendarManager.saveItineraryToCalendar(itinerary)
            } else {
                let granted = await calendarManager.requestAccess()
                if granted {
                    calendarResult = await calendarManager.saveItineraryToCalendar(itinerary)
                }
            }

            await MainActor.run {
                isSavingItinerary = false

                let localSaved: Bool
                let localError: SavedItineraryStorageError?
                switch localSaveResult {
                case .success:
                    localSaved = true
                    localError = nil
                case .failure(let error):
                    localSaved = false
                    localError = error
                }

                let calendarSaved: Bool
                let calendarError: CalendarError?
                switch calendarResult {
                case .success:
                    calendarSaved = true
                    calendarError = nil
                case .failure(let error):
                    calendarSaved = false
                    calendarError = error
                case .none:
                    calendarSaved = false
                    calendarError = nil
                }

                let hasSavedAnything = localSaved || calendarSaved

                if localSaved {
                    isItinerarySavedLocally = true
                    didSaveInCurrentSession = true
                }

                if hasSavedAnything {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCheckmark = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCheckmark = false
                        }
                    }
                }

                if localSaved && calendarSaved {
                    if !compact {
                        saveAlertMessage = String(localized: "L'itinéraire a bien été enregistré dans l'app et dans votre calendrier.")
                        showingSaveAlert = true
                    }
                } else if localSaved && calendarResult == nil {
                    saveAlertMessage = String(localized: "L'itinéraire a été enregistré dans l'app. L'accès au calendrier n'a pas été autorisé.")
                    showingSaveAlert = true
                } else if localSaved && calendarError != nil {
                    saveAlertMessage = String(localized: "L'itinéraire a été enregistré dans l'app, mais pas dans le calendrier : \(calendarError?.localizedDescription ?? "")")
                    showingSaveAlert = true
                } else if calendarSaved && localError != nil {
                    saveAlertMessage = String(localized: "L'itinéraire a été enregistré dans le calendrier, mais pas localement : \(localError?.localizedDescription ?? "")")
                    showingSaveAlert = true
                } else {
                    saveAlertMessage = String(localized: "Erreur lors de l'enregistrement : \(localError?.localizedDescription ?? calendarError?.localizedDescription ?? String(localized: "Une erreur inconnue est survenue."))")
                    showingSaveAlert = true
                }
            }
        }
    }
    
    private func refreshSavedState() {
        savedStateTask?.cancel()
        
        let itinerarySnapshot = itinerary
        savedStateTask = Task(priority: .utility) {
            let isSaved = await SavedItineraryStorage.shared.isSavedAsync(itinerarySnapshot)
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isItinerarySavedLocally = isSaved
                    hasResolvedSavedState = true
                }
            }
        }
    }
    
    private func renderImage() {
        let view = TripResultView(itinerary: itinerary, dontGoToView: true)
            .frame(width: 425)
            .padding(.vertical, 10)
        let renderer = ImageRenderer(content: view)
        renderer.scale = displayScale
        
        if let uiImage = renderer.uiImage {
            renderedUIImage = uiImage
        }
    }
}

// https://stackoverflow.com/a/69694099
// using UIKit is a bit ridiculous here, c'mon Apple..
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
