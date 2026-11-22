import KomareelSourceKit
import AVKit
import Combine
import UIKit

@MainActor
final class FullScreenVideoPlayback: NSObject, @preconcurrency AVPlayerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private let manga: KomareelSourceKit.Manga
    private let episode: KomareelSourceKit.Chapter
    private let source: KomareelSourceKit.Source
    private let controller = AVPlayerViewController()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private weak var presenter: UIViewController?
    private var onDismiss: (() -> Void)?

    private var loadTask: Task<Void, Never>?
    private var session: MediaPlaybackSession?
    private var observers: Set<AnyCancellable> = []
    private var pictureInPicture = false

    init(
        manga: KomareelSourceKit.Manga,
        episode: KomareelSourceKit.Chapter,
        source: KomareelSourceKit.Source,
        onDismiss: @escaping () -> Void
    ) {
        self.manga = manga
        self.episode = episode
        self.source = source
        self.onDismiss = onDismiss
        super.init()

        controller.modalPresentationStyle = .fullScreen
        controller.videoGravity = .resizeAspect
        controller.delegate = self
        controller.loadViewIfNeeded()
        if let overlay = controller.contentOverlayView {
            loadingIndicator.color = .white
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            overlay.addSubview(loadingIndicator)
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
            ])
        }
        loadingIndicator.startAnimating()
    }

    func present(from presenter: UIViewController) {
        self.presenter = presenter
        if let transition = presenter.transitionCoordinator,
           transition.animate(alongsideTransition: nil, completion: { [weak self] context in
               if context.isCancelled {
                   self?.finish()
               } else {
                   self?.presentPlayer(startLoading: true)
               }
           }) {
            return
        }
        presentPlayer(startLoading: true)
    }

    private var canPresent: Bool {
        guard let presenter, presenter.viewIfLoaded?.window != nil,
              presenter.presentedViewController == nil, !presenter.isBeingDismissed else { return false }
        return presenter.navigationController?.topViewController === presenter || presenter.navigationController == nil
    }

    private func presentPlayer(startLoading: Bool) {
        guard canPresent, let presenter else {
            finish()
            return
        }
        presenter.present(controller, animated: true) { [weak self] in
            if startLoading { self?.load() }
        }
        controller.presentationController?.delegate = self
    }

    private func load() {
        guard onDismiss != nil, !controller.isBeingDismissed else { return }
        loadTask?.cancel()
        observers.removeAll()
        session?.stop()
        session = nil
        controller.player = nil
        loadingIndicator.startAnimating()

        loadTask = Task { [weak self, manga, episode, source] in
            do {
                let url = try await source.playbackURL(manga: manga, episode: episode)
                try Task.checkCancellation()
                guard url.scheme?.lowercased() == "https", url.host != nil else {
                    throw URLError(.unsupportedURL)
                }
                self?.startPlayback(url: url)
            } catch {
                if !Task.isCancelled { self?.showPlaybackError() }
            }
        }
    }

    private func startPlayback(url: URL) {
        guard onDismiss != nil, !controller.isBeingDismissed else { return }
        AudioPlaybackController.shared.stop()
        let session = MediaPlaybackSession(url: url, manga: manga, episode: episode)
        let title = AVMutableMetadataItem()
        title.identifier = .commonIdentifierTitle
        title.value = (episode.title ?? manga.title) as NSString
        session.item.externalMetadata = [title]
        self.session = session
        controller.player = session.player

        session.item.publisher(for: \.status)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak session] status in
                guard let self, let session, self.session === session else { return }
                switch status {
                    case .readyToPlay:
                        Task {
                            await session.start()
                            if self.session === session { self.loadingIndicator.stopAnimating() }
                        }
                    case .failed:
                        self.showPlaybackError()
                    default:
                        break
                }
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.didPlayToEndTimeNotification, object: session.item)
            .receive(on: DispatchQueue.main)
            .sink { [weak session] _ in session?.saveProgress(completed: true) }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: AVPlayerItem.failedToPlayToEndTimeNotification, object: session.item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.showPlaybackError() }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak session] _ in session?.saveProgress(force: true) }
            .store(in: &observers)
    }

    private func showPlaybackError() {
        loadingIndicator.stopAnimating()
        guard controller.viewIfLoaded?.window != nil, !controller.isBeingDismissed,
              controller.presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: String(localized: "Couldn’t play this video"),
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: String(localized: "Retry"), style: .default) { [weak self] _ in
            self?.load()
        })
        alert.addAction(UIAlertAction(title: String(localized: "Close"), style: .cancel) { [weak self] _ in
            guard let self, let presenter = self.controller.presentingViewController else { return }
            presenter.dismiss(animated: true) { self.finish() }
        })
        controller.present(alert, animated: true)
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator
    ) {
        coordinator.animate(alongsideTransition: nil) { [weak self] context in
            guard let self, !context.isCancelled, !self.pictureInPicture else { return }
            self.finish()
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if !pictureInPicture { finish() }
    }

    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pictureInPicture = true
    }

    func playerViewController(_ playerViewController: AVPlayerViewController, failedToStartPictureInPictureWithError error: any Error) {
        pictureInPicture = false
    }

    func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        pictureInPicture = false
        if controller.presentingViewController == nil { finish() }
    }

    func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        if controller.presentingViewController != nil {
            completionHandler(true)
        } else if canPresent, let presenter {
            presenter.present(controller, animated: true) { completionHandler(true) }
            controller.presentationController?.delegate = self
        } else {
            completionHandler(false)
        }
    }

    private func finish() {
        guard let onDismiss else { return }
        self.onDismiss = nil
        loadTask?.cancel()
        loadTask = nil
        observers.removeAll()
        session?.stop()
        session = nil
        controller.player = nil
        onDismiss()
    }
}
