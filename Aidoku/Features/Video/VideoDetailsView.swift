import AidokuRunner
import SwiftUI

struct VideoDetailsView: View {
    let source: AidokuRunner.Source
    let manga: AidokuRunner.Manga
    let path: NavigationCoordinator
    let initialEpisodeKey: String?
    let autoplay: Bool

    @State private var details: AidokuRunner.Manga?
    @State private var progress: [String: VideoProgress] = [:]
    @State private var selectedEpisode: AidokuRunner.Chapter?
    @State private var failed = false
    @State private var bookmarked = false
    @State private var changingBookmark = false
    @State private var didHandleInitialPlayback = false
    @State private var descriptionExpanded = false
    @State private var showingCover = false
    @State private var customCover: String?
    @Namespace private var transitionNamespace

    private var episodes: [AidokuRunner.Chapter] { details?.chapters ?? [] }
    private var nextEpisode: AidokuRunner.Chapter? {
        resumeEpisode ?? episodes.first { progress[$0.key]?.completed != true } ?? episodes.first
    }

    private var resumeEpisode: AidokuRunner.Chapter? {
        episodes.compactMap { episode -> (AidokuRunner.Chapter, Date)? in
            guard let entry = progress[episode.key], !entry.completed else { return nil }
            return (episode, entry.updatedAt)
        }.max { $0.1 < $1.1 }?.0
    }

    private var presentedManga: AidokuRunner.Manga {
        var result = details ?? manga
        result.cover = customCover ?? result.cover ?? manga.cover
        if result.description == result.title { result.description = nil }
        return result
    }

    private var playbackTitle: Text {
        if resumeEpisode != nil { return Text("Continue Watching") }
        if nextEpisode != nil { return Text("Play Video") }
        if failed { return Text("Video Unavailable") }
        if details == nil { return Text(NSLocalizedString("LOADING_ELLIPSIS")) }
        return Text("No episodes available")
    }

    private var episodeCountTitle: Text {
        switch episodes.count {
            case 0: Text("Episodes")
            case 1: Text("1 episode")
            default: Text("\(episodes.count) episodes")
        }
    }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 0) {
                MediaDetailsHeaderView(
                    source: source,
                    manga: presentedManga,
                    path: path,
                    bookmarked: bookmarked,
                    transitionNamespace: transitionNamespace,
                    descriptionExpanded: $descriptionExpanded,
                    actionTitle: playbackTitle,
                    actionEnabled: nextEpisode != nil,
                    onCoverPressed: { showingCover = true },
                    onTitlePressed: {
                        (path.rootViewController?.tabBarController as? TabBarController)?.search(for: presentedManga.title)
                    },
                    onPrimaryAction: { selectedEpisode = nextEpisode },
                    metadata: {
                        if let authors = presentedManga.authors, !authors.isEmpty {
                            Text(authors.joined(separator: ", "))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .padding(.bottom, 6)
                                .textSelection(.enabled)
                        }
                    },
                    actions: { headerActions }
                )

                if details != nil || failed {
                    episodeCountTitle
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
                if !episodes.isEmpty {
                    ListDivider()
                }
            }
            .foregroundStyle(.primary)
            .textCase(.none)
            .padding(.top, 10)
            .animation(.default, value: descriptionExpanded)
            .listRowInsets(.zero)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if failed {
                Button("Retry Loading Episodes") {
                    Task { await load() }
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(episodes) { episode in
                    VideoEpisodeRow(source: source, episode: episode, progress: progress[episode.key]) {
                        selectedEpisode = episode
                    }
                    .listRowInsets(.zero)
                }
                if !episodes.isEmpty {
                    ListDivider()
                        .listRowInsets(.zero)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .environment(\.defaultMinListRowHeight, 10)
        .listStyle(.plain)
        .scrollBackgroundHiddenPlease()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if #available(iOS 16.0, *), let url = presentedManga.url {
                        ShareLink(item: url)
                    }
                    if bookmarked {
                        Button(action: showCategories) {
                            Label(NSLocalizedString("EDIT_CATEGORIES"), systemImage: "folder.badge.gearshape")
                        }
                    }
                    Button {
                        Task { await load() }
                    } label: {
                        Label(NSLocalizedString("REFRESH_DETAILS"), systemImage: "arrow.clockwise")
                    }
                } label: {
                    MoreIcon()
                }
            }
        }
        .refreshable { await load() }
        .fullScreenCover(item: $selectedEpisode, onDismiss: refreshProgress) { episode in
            VideoPlaybackView(manga: details ?? manga, episode: episode, source: source)
        }
        .fullScreenCover(
            isPresented: $showingCover,
            onDismiss: { Task { await refreshStoredCover() } },
            content: {
                MangaCoverPageView(source: source, manga: presentedManga, inLibrary: bookmarked)
                    .navigationTransitionZoom(sourceID: manga.identifier, in: transitionNamespace)
            }
        )
        .onAppear(perform: refreshProgress)
        .task {
            await refreshBookmark()
            await refreshStoredCover()
            await load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateLibrary)) { _ in
            Task { await refreshBookmark() }
        }
    }

    private var headerActions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await changeBookmark() }
            } label: {
                Image(systemName: "bookmark.fill")
            }
            .buttonStyle(MangaActionButtonStyle(selected: bookmarked))
            .accessibilityLabel(NSLocalizedString(bookmarked ? "REMOVE_FROM_LIBRARY" : "ADD_TO_LIBRARY"))
            .disabled(changingBookmark)
            .contextMenu {
                if bookmarked {
                    Button(action: showCategories) {
                        Label(NSLocalizedString("CATEGORIES"), systemImage: "folder")
                    }
                }
            }
            if let url = presentedManga.url {
                MediaDetailsSourceButton(url: url, path: path)
            }
        }
    }

    private func refreshProgress() {
        progress = VideoHistory.progress(for: manga.identifier)
    }

    private func refreshBookmark() async {
        let id = manga.identifier
        bookmarked = await CoreDataManager.shared.container.performBackgroundTask { context in
            CoreDataManager.shared.hasLibraryManga(mangaId: id, context: context)
        }
    }

    private func refreshStoredCover() async {
        let id = manga.identifier
        customCover = await CoreDataManager.shared.container.performBackgroundTask { context in
            guard CoreDataManager.shared.hasEditedKey(mangaId: id, key: .cover, context: context) else { return nil }
            return CoreDataManager.shared.getManga(mangaId: id, context: context)?.toNewManga().cover
        }
    }

    private func showCategories() {
        path.present(UINavigationController(rootViewController: CategorySelectViewController(manga: details ?? manga)))
    }

    private func changeBookmark() async {
        guard !changingBookmark else { return }
        changingBookmark = true
        defer { changingBookmark = false }
        if bookmarked {
            await MangaManager.shared.removeFromLibrary(mangaId: manga.identifier)
        } else if await MangaManager.shouldAskForCategories() {
            showCategories()
        } else {
            await MangaManager.shared.addToLibrary(manga: details ?? manga, chapters: episodes)
        }
        await refreshBookmark()
    }

    private func load() async {
        failed = false
        do {
            let result = try await source.getMangaUpdate(manga: manga, needsDetails: true, needsChapters: true)
            try Task.checkCancellation()
            details = result
            if !didHandleInitialPlayback {
                didHandleInitialPlayback = true
                if let initialEpisodeKey {
                    selectedEpisode = episodes.first { $0.key == initialEpisodeKey }
                } else if autoplay {
                    selectedEpisode = nextEpisode
                }
            }
        } catch {
            if !Task.isCancelled { failed = true }
        }
    }
}

private struct VideoEpisodeRow: View {
    let source: AidokuRunner.Source
    let episode: AidokuRunner.Chapter
    let progress: VideoProgress?
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            ChapterTableCell(
                source: source,
                sourceKey: source.key,
                chapter: episode,
                read: progress?.completed == true,
                page: nil,
                downloadStatus: .none,
                displayMode: .default,
                titleOverride: episode.title ?? episode.key,
                progressSubtitle: progressSubtitle
            )
        }
        .tint(.primary)
    }

    private var progressSubtitle: Text? {
        guard let progress else { return nil }
        if progress.completed { return Text("Watched") }
        return Self.positionFormatter.string(from: progress.position).map { Text("Resume at \($0)") }
    }

    private static let positionFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}
