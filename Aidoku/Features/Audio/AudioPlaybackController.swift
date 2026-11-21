import AidokuRunner
import AVFoundation
import Combine
import MediaPlayer
import UIKit

@MainActor
final class AudioPlaybackController: ObservableObject {
    static let shared = AudioPlaybackController()

    struct Episode {
        let manga: AidokuRunner.Manga
        let chapter: AidokuRunner.Chapter
        let source: AidokuRunner.Source

        var title: String { chapter.title ?? manga.title }
    }

    enum Status {
        case idle
        case loading
        case ready
        case failed
    }

    @Published private(set) var episode: Episode?
    @Published private(set) var status = Status.idle
    private(set) var session: MediaPlaybackSession?
    private var loadingTask: Task<Void, Never>?
    private var observers: Set<AnyCancellable> = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var audioSessionActive = false
    private var resumeAfterInterruption = false
    @Published private(set) var playbackRequested = false

    private var position: Double {
        let seconds = session?.player.currentTime().seconds ?? 0
        return seconds.isFinite ? max(0, seconds) : 0
    }

    private var duration: Double {
        let seconds = session?.item.duration.seconds ?? 0
        return seconds.isFinite && seconds > 0 ? seconds : 0
    }

    private init() {}

    func open(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter, source: AidokuRunner.Source) {
        guard self.episode?.manga.identifier != manga.identifier || self.episode?.chapter.key != episode.key else { return }
        load(.init(manga: manga, chapter: episode, source: source))
    }

    func retry() {
        if let episode { load(episode) }
    }

    private func load(_ episode: Episode) {
        stop()
        self.episode = episode
        status = .loading
        loadingTask = Task {
            do {
                let url = try await episode.source.playbackURL(manga: episode.manga, episode: episode.chapter)
                try Task.checkCancellation()
                guard url.scheme?.lowercased() == "https", url.host != nil else {
                    throw URLError(.unsupportedURL)
                }
                let session = MediaPlaybackSession(url: url, manga: episode.manga, episode: episode.chapter)
                session.player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
                self.session = session
                observe(session)
            } catch {
                if !Task.isCancelled { status = .failed }
            }
        }
    }

    private func observe(_ session: MediaPlaybackSession) {
        session.item.publisher(for: \.status)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak session] status in
                guard let self, let session, self.session === session else { return }
                switch status {
                    case .readyToPlay:
                        Task { await self.start(session) }
                    case .failed:
                        self.fail()
                    default:
                        break
                }
            }
            .store(in: &observers)

        session.player.publisher(for: \.timeControlStatus)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak session] status in
                guard let self, let session, self.session === session, self.status == .ready else { return }
                if status == .paused {
                    session.saveProgress(force: true)
                }
                self.playbackRequested = status != .paused
                self.updateNowPlaying()
            }
            .store(in: &observers)

        session.player.publisher(for: \.rate)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateNowPlaying() }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: session.item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.session?.saveProgress(completed: true)
                self.playbackRequested = false
                self.updateNowPlaying()
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.timeJumpedNotification, object: session.item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak session] _ in
                guard let self, let session, self.session === session, self.status == .ready else { return }
                session.saveProgress(force: true)
                self.updateNowPlaying()
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: session.item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.fail() }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleInterruption($0) }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
                    self?.pause()
                }
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak session] _ in session?.saveProgress(force: true) }
            .store(in: &observers)
    }

    private func start(_ session: MediaPlaybackSession) async {
        await session.start(autoplay: false)
        guard self.session === session, status == .loading else { return }
        status = .ready
        installRemoteCommands()
        play()
    }

    func togglePlayback() {
        if let session, session.player.timeControlStatus != .paused {
            pause()
        } else {
            play()
        }
    }

    private func play() {
        guard let session, status == .ready else { return }
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, mode: .spokenAudio)
            try audio.setActive(true)
            audioSessionActive = true
            if duration > 0, position >= duration {
                seek(to: 0)
            }
            playbackRequested = true
            session.player.play()
        } catch {
            LogManager.logger.error("Failed to activate podcast playback: \(error)")
            fail()
        }
    }

    private func pause() {
        playbackRequested = false
        resumeAfterInterruption = false
        session?.player.pause()
        session?.saveProgress(force: true)
        updateNowPlaying()
    }

    private func seek(to seconds: Double) {
        guard let session, duration > 0, seconds.isFinite else { return }
        let time = min(max(0, seconds), duration)
        session.player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    func stop() {
        loadingTask?.cancel()
        loadingTask = nil
        observers.removeAll()
        session?.stop()
        session = nil
        if !remoteTargets.isEmpty {
            remoteTargets.forEach { $0.0.removeTarget($0.1) }
            remoteTargets.removeAll()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
        if audioSessionActive {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            audioSessionActive = false
        }
        episode = nil
        status = .idle
        playbackRequested = false
        resumeAfterInterruption = false
    }

    private func fail() {
        let episode = episode
        stop()
        self.episode = episode
        status = .failed
    }

    private func handleInterruption(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
        switch AVAudioSession.InterruptionType(rawValue: type) {
            case .began:
                let wasPlaying = playbackRequested
                pause()
                resumeAfterInterruption = wasPlaying
            case .ended:
                let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if resumeAfterInterruption, AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    play()
                }
                resumeAfterInterruption = false
            default:
                break
        }
    }

    private func installRemoteCommands() {
        let commands = MPRemoteCommandCenter.shared()
        addRemoteTarget(commands.playCommand) { $0.play() }
        addRemoteTarget(commands.pauseCommand) { $0.pause() }
        addRemoteTarget(commands.togglePlayPauseCommand) { $0.togglePlayback() }
        let seek = commands.changePlaybackPositionCommand
        let token = seek.addTarget { [weak self] event in
            guard let time = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else { return .commandFailed }
            Task { @MainActor in self?.seek(to: time) }
            return .success
        }
        remoteTargets.append((seek, token))
    }

    private func addRemoteTarget(_ command: MPRemoteCommand, action: @escaping @MainActor (AudioPlaybackController) -> Void) {
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor in
                if let self { action(self) }
            }
            return .success
        }
        remoteTargets.append((command, token))
    }

    private func updateNowPlaying() {
        guard let episode, status == .ready, let player = session?.player else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: episode.title,
            MPMediaItemPropertyAlbumTitle: episode.manga.title,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: player.timeControlStatus == .playing ? player.rate : 0
        ]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
