import AidokuRunner
import SwiftUI

struct VideoDetailsView: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga

    @State private var details: AidokuRunner.Manga?
    @State private var progress: [String: VideoProgress] = [:]
    @State private var selectedEpisode: AidokuRunner.Chapter?
    @State private var failed = false

    private static let positionFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    private var episodes: [AidokuRunner.Chapter] { details?.chapters ?? [] }

    private var resumeEpisode: AidokuRunner.Chapter? {
        episodes.compactMap { episode -> (AidokuRunner.Chapter, Date)? in
            guard let entry = progress[episode.key], !entry.completed else { return nil }
            return (episode, entry.updatedAt)
        }.max { $0.1 < $1.1 }?.0
    }

    var body: some View {
        List {
            Section {
                header
                if let episode = resumeEpisode ?? episodes.first(where: { progress[$0.key]?.completed != true }) ?? episodes.first {
                    Button {
                        selectedEpisode = episode
                    } label: {
                        let title: LocalizedStringKey = resumeEpisode == nil ? "Play Video" : "Continue Watching"
                        Label(title, systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowSeparator(.hidden)
                }
            }

            Section("Episodes") {
                if failed {
                    Button("Retry Loading Episodes") {
                        Task { await load() }
                    }
                } else if details == nil {
                    ProgressView()
                } else if episodes.isEmpty {
                    Text("No episodes available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(episodes) { episode in
                        episodeRow(episode)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $selectedEpisode, onDismiss: refreshProgress) { episode in
            VideoPlaybackView(manga: details ?? manga, episode: episode, source: source)
        }
        .onAppear(perform: refreshProgress)
        .task { await load() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            if let cover = manga.cover {
                MangaCoverView(source: source, coverImage: cover, width: 100, height: 100)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(details?.title ?? manga.title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                if let description = details?.description ?? manga.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func episodeRow(_ episode: AidokuRunner.Chapter) -> some View {
        Button {
            selectedEpisode = episode
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title ?? episode.key)
                        .foregroundStyle(.primary)
                    if let entry = progress[episode.key] {
                        if entry.completed {
                            Text("Watched")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let time = Self.positionFormatter.string(from: entry.position) {
                            Text("Resume at \(time)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func refreshProgress() {
        progress = VideoHistory.progress(for: manga.identifier)
    }

    private func load() async {
        failed = false
        do {
            let result = try await source.getMangaUpdate(manga: manga, needsDetails: true, needsChapters: true)
            try Task.checkCancellation()
            details = result
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}
