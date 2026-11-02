import SwiftUI

/// Music tab — honest unavailable until official audio rights/API are confirmed.
struct MusicPlaceholderView: View {
    var body: some View {
        VKUnavailableState(
            title: "Music unavailable",
            details: "Playback stays disabled until official VK audio access and content rights are confirmed for this app. No private scrapers or third-party tokens."
        )
        .background(VKStyle.groupedCanvas)
        .navigationTitle("Музыка")
    }
}

#Preview {
    NavigationStack { MusicPlaceholderView() }
}
