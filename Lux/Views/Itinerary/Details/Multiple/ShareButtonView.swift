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
    
    @State private var showingShareDialog = false
    @State private var renderedImage: Image?
    @State private var isUploading = false
    @State private var uploadedURL: String?
    @State private var showingShareSheet = false
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        Button(action: {
            showingShareDialog = true
        }) {
            HStack {
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isUploading ? "Partage..." : "Partager")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 35)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 35)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
        }
        .disabled(isUploading)
        .confirmationDialog("Partager l'itinéraire", isPresented: $showingShareDialog, titleVisibility: .visible) {
            Button("Partager l'entiereté") {
                uploadItinerary()
            }
            
            if let image = renderedImage {
                ShareLink("Partager l'aperçu en tant qu'image", item: image, preview: SharePreview("Aperçu de l'itinéraire", image: image))
            }
            
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("Choisissez comment vous souhaitez partager cet itinéraire.\nLe partage de l'ensemble de l'itinéraire requiert que son receveur ait l'app.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = uploadedURL {
                ShareSheet(items: [url])
            }
        }
        .onAppear {
            renderImage()
        }
    }
    
    private func uploadItinerary() {
        isUploading = true
        showingShareDialog = false
        
        Task {
            let result = await itineraarySharer.uploadItinerary(itinerary)
            
            await MainActor.run {
                isUploading = false
                
                switch result {
                case .success(let identifier):
                    uploadedURL = "https://lux.cclerc.ch/share#\(identifier)"
                    showingShareSheet = true
                case .failure(let error):
                    print("upload failed !! \(error)")
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
