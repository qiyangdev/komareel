import AidokuRunner
import AVKit
import SwiftUI

struct MediaPlaybackScreen<PlayerContent: View>: View {
    let title: String
    let loading: Bool
    let failed: Bool
    let loadingTitle: LocalizedStringKey
    let failureTitle: LocalizedStringKey
    let onClose: () -> Void
    let onRetry: () -> Void
    let onStop: (() -> Void)?
    let playerContent: PlayerContent

    init(
        title: String,
        loading: Bool,
        failed: Bool,
        loadingTitle: LocalizedStringKey,
        failureTitle: LocalizedStringKey,
        onClose: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        @ViewBuilder playerContent: () -> PlayerContent
    ) {
        self.title = title
        self.loading = loading
        self.failed = failed
        self.loadingTitle = loadingTitle
        self.failureTitle = failureTitle
        self.onClose = onClose
        self.onRetry = onRetry
        self.onStop = onStop
        self.playerContent = playerContent()
    }

    var body: some View {
        PlatformNavigationStack {
            ZStack {
                Color.black
                playerContent
                if failed {
                    VStack(spacing: 12) {
                        Text(failureTitle)
                        Button("Retry", action: onRetry).buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black, in: RoundedRectangle(cornerRadius: 12))
                } else if loading {
                    ProgressView(loadingTitle)
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton(action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let onStop {
                        Button("Stop", action: onStop)
                    }
                }
            }
        }
    }
}

struct NativeAudioPlayer: UIViewControllerRepresentable {
    let session: MediaPlaybackSession
    let artwork: MediaPlaybackArtwork

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.updatesNowPlayingInfoCenter = false
        controller.allowsPictureInPicturePlayback = false
        controller.videoGravity = .resizeAspect
        controller.player = session.player
        controller.loadViewIfNeeded()
        if let overlay = controller.contentOverlayView {
            let host = UIHostingController(rootView: artwork)
            controller.addChild(host)
            host.view.isUserInteractionEnabled = false
            host.view.backgroundColor = .clear
            host.view.frame = overlay.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.addSubview(host.view)
            host.didMove(toParent: controller)
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}

struct MediaPlaybackArtwork: View {
    let source: AidokuRunner.Source
    let cover: String

    var body: some View {
        GeometryReader { geometry in
            let size = min(280, min(geometry.size.width, geometry.size.height) * 0.65)
            MangaCoverView(source: source, coverImage: cover, width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
