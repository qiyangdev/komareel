import KomareelSourceKit
import AVFoundation

@MainActor
final class MediaPlaybackSession {
    let player: AVPlayer
    let item: AVPlayerItem

    private let manga: KomareelSourceKit.Manga
    private let episode: KomareelSourceKit.Chapter
    private var timeObserver: Any?
    private var started = false
    private var ready = false
    private var stopped = false
    private var completed = false
    private var lastSavedPosition: Double?
    private var lastSavedAt: Date?

    init(url: URL, manga: KomareelSourceKit.Manga, episode: KomareelSourceKit.Chapter) {
        let item = AVPlayerItem(url: url)
        self.item = item
        self.player = AVPlayer(playerItem: item)
        self.manga = manga
        self.episode = episode
    }

    func start(autoplay: Bool = true) async {
        guard !started, !stopped else { return }
        started = true

        if let progress = MediaPlaybackHistory.progress(for: manga.identifier)[episode.key],
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
        if autoplay { player.play() }
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
        guard MediaPlaybackHistory.save(
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
