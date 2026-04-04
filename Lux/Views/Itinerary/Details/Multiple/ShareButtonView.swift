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
    
    @State private var showingShareDialog = false
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var isUploading = false
    @State private var isSavingToCalendar = false
    @State private var uploadedURL: String?
    @State private var showingShareSheet = false
    @State private var showingImageShareSheet = false
    @State private var showingCalendarAlert = false
    @State private var calendarAlertMessage = ""
    @State private var showCheckmark = false
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        Group {
            if compact {
                Menu {
                    Button {
                        uploadItinerary()
                    } label: {
                        Label("Partager l'entiereté", systemImage: "link")
                    }
                    
                    if renderedUIImage != nil {
                        Button {
                            showingImageShareSheet = true
                        } label: {
                            Label("Partager l'aperçu en tant qu'image", systemImage: "photo")
                        }
                    }
                    
                    Button {
                        saveToCalendar()
                    } label: {
                        Label("Enregistrer dans Calendrier", systemImage: "calendar.badge.plus")
                    }
                } label: {
                    HStack {
                        if isUploading || isSavingToCalendar {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if showCheckmark {
                            Image(systemName: "checkmark")
                                .font(.headline)
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                                .offset(y: -1)
                        }
                    }
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
                .disabled(isUploading || isSavingToCalendar)
            } else {
                Button(action: {
                    showingShareDialog = true
                }) {
                    HStack {
                        if isUploading || isSavingToCalendar {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isUploading ? "Partage..." : isSavingToCalendar ? "Enregistrement..." : "Partager")
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
                .disabled(isUploading || isSavingToCalendar)
                .confirmationDialog("Partager l'itinéraire", isPresented: $showingShareDialog, titleVisibility: .visible) {
                    Button("Partager l'entiereté") {
                        uploadItinerary()
                    }
                    
                    if let image = renderedImage {
                        ShareLink("Partager l'aperçu en tant qu'image", item: image, preview: SharePreview("Aperçu de l'itinéraire", image: image))
                    }
                    
                    Button("Enregistrer dans Calendrier") {
                        saveToCalendar()
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
        .alert("Calendrier", isPresented: $showingCalendarAlert) {
            Button("OK") { }
        } message: {
            Text(calendarAlertMessage)
        }
        .onAppear {
            renderImage()
        }
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
    
    private func saveToCalendar() {
        let calendarManager = CalendarManager(itinerarySharer: itineraarySharer)
        isSavingToCalendar = true
        showingShareDialog = false
        
        Task {
            if calendarManager.authorizationStatus != .fullAccess {
                let granted = await calendarManager.requestAccess()
                if !granted {
                    await MainActor.run {
                        isSavingToCalendar = false
                        if compact {
                            calendarAlertMessage = String(localized: "L'accès au calendrier est requis pour enregistrer l'itinéraire. Veuillez autoriser l'accès dans les Réglages.")
                            showingCalendarAlert = true
                        } else {
                            calendarAlertMessage = String(localized: "L'accès au calendrier est requis pour enregistrer l'itinéraire. Veuillez autoriser l'accès dans les Réglages.")
                            showingCalendarAlert = true
                        }
                    }
                    return
                }
            }
            
            let result = await calendarManager.saveItineraryToCalendar(itinerary)
            
            await MainActor.run {
                isSavingToCalendar = false
                
                switch result {
                case .success(_):
                    if compact {
                        showCheckmark = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation {
                                showCheckmark = false
                            }
                        }
                    } else {
                        calendarAlertMessage = String(localized: "L'itinéraire a bien été enregistré dans votre calendrier !")
                        showingCalendarAlert = true
                    }
                case .failure(let error):
                    calendarAlertMessage = String(localized: "Erreur lors de l'enregistrement : \(error.localizedDescription)")
                    showingCalendarAlert = true
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
            renderedImage = Image(uiImage: uiImage)
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
