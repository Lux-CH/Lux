import SwiftUI

struct OfflineModeBadge: View {
    @EnvironmentObject private var offline: OfflineManager

    var body: some View {
        if offline.isOfflineActive {
            HStack(spacing: 6) {
                Image(systemName: "icloud.slash")
                Text("Mode hors ligne")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
            .transition(.opacity)
        }
    }
}