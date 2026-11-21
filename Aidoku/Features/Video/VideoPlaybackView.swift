import AidokuRunner
import AVKit
import Combine
import SwiftUI

struct VideoPlaybackView: View {
    let manga: AidokuRunner.Manga
    let episode: AidokuRunner.Chapter
    let source: AidokuRunner.Source

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var session: MediaPlaybackSession?
    @State private var loading = true
    @State private var failed = false
    @State private var attempt = 0
    @State private var startedAttempt: Int?

    var body: some View {
        MediaPlaybackScreen(
            title: episode.title ?? manga.title,
            loading: loading,
            failed: failed,
            loadingTitle: "Loading Video",
            failureTitle: "Couldn’t play this video",
            onClose: close,
            onRetry: retry
        ) {
            if let session {
                NativeMediaPlayer(session: session)
                    .id(ObjectIdentifier(session))
                    .onReceive(session.item.publisher(for: \.status).receive(on: DispatchQueue.main)) { status in
                        guard self.session === session else { return }
                        switch status {
                            case .readyToPlay:
                                Task {
                                    await session.start()
                                    if self.session === session { loading = false }
                                }
                            case .failed:
                                failed = true
                            default:
                                break
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(
                        for: AVPlayerItem.didPlayToEndTimeNotification,
                        object: session.item
                    ).receive(on: DispatchQueue.main)) { _ in
                        session.saveProgress(completed: true)
                    }
                    .onReceive(NotificationCenter.default.publisher(
                        for: AVPlayerItem.failedToPlayToEndTimeNotification,
                        object: session.item
                    ).receive(on: DispatchQueue.main)) { _ in
                        if self.session === session { failed = true }
                    }
            }
        }
        .task(id: attempt) {
            // AVKit can temporarily cover the playback page during its full-screen presentation.
            guard startedAttempt != attempt else { return }
            startedAttempt = attempt
            session?.stop()
            session = nil
            loading = true
            failed = false
            do {
                let url = try await source.playbackURL(manga: manga, episode: episode)
                try Task.checkCancellation()
                guard url.scheme?.lowercased() == "https", url.host != nil else {
                    throw URLError(.unsupportedURL)
                }
                AudioPlaybackController.shared.stop()
                session = MediaPlaybackSession(url: url, manga: manga, episode: episode)
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
        .onChangeWrapper(of: scenePhase) { _, phase in
            if phase == .background { session?.saveProgress(force: true) }
        }
    }

    private func close() {
        session?.stop()
        dismiss()
    }

    private func retry() {
        attempt += 1
    }
}
