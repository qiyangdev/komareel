import SwiftUI

struct AudioPlaybackAccessoryView: View {
    @ObservedObject var player: AudioPlaybackController
    let onOpen: () -> Void

    var body: some View {
        if let episode = player.episode {
            HStack(spacing: 8) {
                Button(action: onOpen) {
                    HStack(spacing: 8) {
                        MangaCoverView(
                            source: episode.source,
                            coverImage: episode.manga.cover ?? "",
                            width: 32,
                            height: 32,
                            downsampleWidth: 32
                        )
                        .accessibilityHidden(true)
                        Text(episode.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(episode.title))
                .accessibilityHint(Text("Opens Now Playing"))

                if player.status == .loading {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Loading Audio")
                } else if player.status == .ready {
                    Button(action: player.togglePlayback) {
                        Image(systemName: player.playbackRequested ? "pause.fill" : "play.fill")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(player.playbackRequested ? Text("Pause") : Text("Play"))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
