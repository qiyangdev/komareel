import SwiftUI

struct AudioPlaybackView: View {
    @ObservedObject var player: AudioPlaybackController
    var onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MediaPlaybackScreen(
            title: player.episode?.title ?? String(localized: "Now Playing"),
            loading: player.status == .loading,
            failed: player.status == .failed,
            loadingTitle: "Loading Audio",
            failureTitle: "Couldn’t play this audio",
            onClose: close,
            onRetry: player.retry,
            onStop: stopAction
        ) {
            playbackContent
        }
    }

    private var stopAction: (() -> Void)? {
        guard player.status != .idle else { return nil }
        return { stop() }
    }

    @ViewBuilder private var playbackContent: some View {
        if player.status == .ready, let session = player.session, let episode = player.episode {
            let artwork = MediaPlaybackArtwork(source: episode.source, cover: episode.manga.cover ?? "")
            NativeAudioPlayer(session: session, artwork: artwork)
                .id(ObjectIdentifier(session))
        }
    }

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func stop() {
        player.stop()
        close()
    }
}
