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
    @State private var session: VideoPlaybackSession?
    @State private var loading = true
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        PlatformNavigationStack {
            ZStack {
                Color.black
                if let session {
                    VideoPlayer(player: session.player)
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

                if failed {
                    VStack(spacing: 12) {
                        Text("Couldn’t play this video")
                        Button("Retry") {
                            attempt += 1
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                } else if loading {
                    ProgressView("Loading Video")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(episode.title ?? manga.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        session?.stop()
                        dismiss()
                    }
                }
            }
        }
        .task(id: attempt) {
            session?.stop()
            session = nil
            loading = true
            failed = false
            do {
                let url = try await source.videoURL(manga: manga, episode: episode)
                try Task.checkCancellation()
                guard url.scheme?.lowercased() == "https", url.host != nil else {
                    throw URLError(.unsupportedURL)
                }
                session = VideoPlaybackSession(url: url, manga: manga, episode: episode)
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
        .onDisappear { session?.stop() }
        .onChangeWrapper(of: scenePhase) { _, phase in
            if phase == .background { session?.saveProgress(force: true) }
        }
    }
}

@MainActor
private final class VideoPlaybackSession {
    let player: AVPlayer
    let item: AVPlayerItem

    private let manga: AidokuRunner.Manga
    private let episode: AidokuRunner.Chapter
    private var timeObserver: Any?
    private var started = false
    private var ready = false
    private var stopped = false
    private var completed = false
    private var lastSavedPosition: Double?
    private var lastSavedAt: Date?

    init(url: URL, manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) {
        let item = AVPlayerItem(url: url)
        self.item = item
        self.player = AVPlayer(playerItem: item)
        self.manga = manga
        self.episode = episode
    }

    func start() async {
        guard !started, !stopped else { return }
        started = true

        if let progress = VideoHistory.progress(for: manga.identifier)[episode.key],
           !progress.completed,
           progress.position.isFinite,
           progress.position > 0,
           !item.duration.seconds.isFinite || progress.position < item.duration.seconds {
            let position = CMTime(seconds: progress.position, preferredTimescale: 600)
            _ = await player.seek(to: position, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        guard !stopped else { return }

        ready = true
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 2, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveProgress() }
        }
        player.play()
    }

    func saveProgress(completed: Bool = false, force: Bool = false) {
        guard ready, !stopped, !self.completed, !AppSettings.general.incognitoMode.get() else { return }
        let now = Date.now
        if !force, !completed, let lastSavedAt, now.timeIntervalSince(lastSavedAt) < 10 { return }
        let position = player.currentTime().seconds
        let duration = item.duration.seconds
        guard position.isFinite, duration.isFinite, duration > 0, completed || position >= 1 else { return }
        let savedPosition = completed ? duration : min(position, duration)
        guard completed || lastSavedPosition != savedPosition else { return }

        let firstSave = lastSavedPosition == nil
        guard VideoHistory.save(
            .init(position: savedPosition, duration: duration, completed: completed, updatedAt: now),
            manga: manga,
            episode: episode
        ) else { return }
        self.completed = completed
        lastSavedPosition = savedPosition
        lastSavedAt = now
        if firstSave || completed {
            notifyHistoryChanged()
        }
    }

    func stop() {
        guard !stopped else { return }
        player.pause()
        saveProgress(force: true)
        if lastSavedPosition != nil, !completed { notifyHistoryChanged() }
        stopped = true
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        player.replaceCurrentItem(with: nil)
    }

    private func notifyHistoryChanged() {
        let id = ChapterIdentifier(sourceKey: manga.sourceKey, mangaKey: manga.key, chapterKey: episode.key)
        NotificationCenter.default.post(name: .historySet, object: (chapterId: id, page: -1))
    }
}
