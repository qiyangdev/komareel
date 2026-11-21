//
//  MangaDetailsHeaderView.swift
//  Aidoku
//
//  Created by Skitty on 8/18/23.
//

import SwiftUI
import AidokuRunner
import MarkdownUI
import NukeUI

struct MangaDetailsHeaderView: View {
    @Binding var source: AidokuRunner.Source?

    @Binding var manga: AidokuRunner.Manga
    @Binding var chapters: [AidokuRunner.Chapter]
    @Binding var nextChapter: AidokuRunner.Chapter?
    @Binding var readingInProgress: Bool
    @Binding var allChaptersLocked: Bool
    @Binding var allChaptersRead: Bool
    @Binding var initialDataLoaded: Bool

    @Binding var bookmarked: Bool
    @Binding var hasCategories: Bool
    @Binding var coverPressed: Bool
    @Binding var chapterSortOption: ChapterSortOption
    @Binding var chapterSortAscending: Bool

    @Binding var filters: [ChapterFilterOption]
    @Binding var langFilter: String?
    @Binding var scanlatorFilter: [String]

    @Binding var descriptionExpanded: Bool

    @Binding var chapterTitleDisplayMode: ChapterTitleDisplayMode

    var hasOtherDownloads: Bool
    var transitionNamespace: Namespace.ID
    var onTitlePressed: (() -> Void)?
    var onTrackerButtonPressed: (() -> Void)?
    var onReadButtonPressed: (() -> Void)?

    @EnvironmentObject private var path: NavigationCoordinator

    @State private var readButtonText = NSLocalizedString("LOADING_ELLIPSIS")
    @State private var readButtonDisabled = true
    @State private var animationTrigger = false
    @State private var longHeldBookmark = false
    @State private var isTracking = false
    @State private var hasAvailableTrackers = false
    @State private var showLibraryRemoveConfirm = false

    init(
        source: Binding<AidokuRunner.Source?>,
        manga: Binding<AidokuRunner.Manga>,
        chapters: Binding<[AidokuRunner.Chapter]>,
        nextChapter: Binding<AidokuRunner.Chapter?>,
        readingInProgress: Binding<Bool>,
        allChaptersLocked: Binding<Bool>,
        allChaptersRead: Binding<Bool>,
        initialDataLoaded: Binding<Bool>,
        bookmarked: Binding<Bool>,
        hasCategories: Binding<Bool>,
        coverPressed: Binding<Bool>,
        chapterSortOption: Binding<ChapterSortOption>,
        chapterSortAscending: Binding<Bool>,
        filters: Binding<[ChapterFilterOption]>,
        langFilter: Binding<String?>,
        scanlatorFilter: Binding<[String]>,
        descriptionExpanded: Binding<Bool>,
        chapterTitleDisplayMode: Binding<ChapterTitleDisplayMode>,
        hasOtherDownloads: Bool,
        transitionNamespace: Namespace.ID,
        onTitlePressed: (() -> Void)? = nil,
        onTrackerButtonPressed: (() -> Void)? = nil,
        onReadButtonPressed: (() -> Void)? = nil
    ) {
        self._source = source
        self._manga = manga
        self._chapters = chapters
        self._nextChapter = nextChapter
        self._readingInProgress = readingInProgress
        self._allChaptersLocked = allChaptersLocked
        self._allChaptersRead = allChaptersRead
        self._initialDataLoaded = initialDataLoaded
        self._bookmarked = bookmarked
        self._hasCategories = hasCategories
        self._coverPressed = coverPressed
        self._chapterSortOption = chapterSortOption
        self._chapterSortAscending = chapterSortAscending
        self._filters = filters
        self._langFilter = langFilter
        self._scanlatorFilter = scanlatorFilter
        self._descriptionExpanded = descriptionExpanded
        self._chapterTitleDisplayMode = chapterTitleDisplayMode
        self.hasOtherDownloads = hasOtherDownloads
        self.transitionNamespace = transitionNamespace
        self.onTitlePressed = onTitlePressed
        self.onTrackerButtonPressed = onTrackerButtonPressed
        self.onReadButtonPressed = onReadButtonPressed

        self._isTracking = State(initialValue: TrackerManager.shared.isTracking(
            mangaId: manga.wrappedValue.identifier
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MediaDetailsHeaderView(
                source: source,
                manga: manga,
                path: path,
                bookmarked: bookmarked,
                transitionNamespace: transitionNamespace,
                descriptionExpanded: $descriptionExpanded,
                actionTitle: Text(readButtonText),
                actionEnabled: !readButtonDisabled,
                onCoverPressed: { coverPressed = true },
                onTitlePressed: { onTitlePressed?() },
                onPrimaryAction: { onReadButtonPressed?() },
                metadata: { authorView },
                actions: { buttonsView }
            )

            // hide the chapter list header if there are no chapters and the other downloads header is shown
            if !(manga.chapters ?? chapters).isEmpty || !hasOtherDownloads {
                ChapterListHeaderView(
                    allChapters: manga.chapters,
                    filteredChapters: manga.chapters != nil ? chapters : (initialDataLoaded ? [] : nil),
                    sortOption: $chapterSortOption,
                    sortAscending: $chapterSortAscending,
                    filters: $filters,
                    langFilter: $langFilter,
                    scanlatorFilter: $scanlatorFilter,
                    displayMode: $chapterTitleDisplayMode,
                    mangaId: manga.identifier
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }

            // separator
            if !chapters.isEmpty {
                ListDivider()
            }
        }
        .animation(.default, value: animationTrigger)
        .animation(.default, value: descriptionExpanded)
        .foregroundStyle(.primary)
        .textCase(.none)
        .padding(.top, 10)
        .onChange(of: manga) { _ in
            animationTrigger.toggle()
        }
        .onChange(of: nextChapter) { _ in
            updateReadButtonText()
        }
        .onChange(of: readingInProgress) { _ in
            updateReadButtonText()
        }
        .onChange(of: allChaptersLocked) { _ in
            updateReadButtonText()
        }
        .onChange(of: allChaptersRead) { _ in
            updateReadButtonText()
        }
        .onChange(of: source != nil) { _ in
            updateReadButtonText()
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateTrackers)) { _ in
            isTracking = TrackerManager.shared.isTracking(mangaId: manga.identifier)
        }
        .task {
            updateReadButtonText()
            hasAvailableTrackers = await TrackerManager.shared.hasAvailableTrackers(mangaId: manga.identifier)
        }
    }

    @ViewBuilder
    private var authorView: some View {
        if let authors = manga.authors, !authors.isEmpty {
            let label = Text(authors.joined(separator: ", "))
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .font(.callout)
                .padding(.bottom, 6)
                .textSelection(.enabled)
                .transition(.opacity)

            if let source, source.supportsAuthorSearch {
                Button {
                    // we'll need a better ui in the future for different author selection
                    guard let author = authors.first else { return }

                    let viewController = MangaListViewController(source: source, title: author)
                    viewController.getEntries = { page in
                        try await source.getSearchMangaList(query: nil, page: page, filters: [
                            .text(id: "author", value: author)
                        ])
                    }
                    path.push(viewController)
                } label: {
                    label
                }
                .buttonStyle(.borderless)
            } else {
                label
            }
        }
    }

    var buttonsView: some View {
        HStack(spacing: 8) {
            Button {
                // long holding also triggers a press on release, so cancel that
                if longHeldBookmark {
                    longHeldBookmark = false
                    return
                }
                if bookmarked && isTracking {
                    // show confirm prompt
                    showLibraryRemoveConfirm = true
                } else {
                    Task {
                        await toggleBookmarked()
                    }
                }
            } label: {
                Image(systemName: "bookmark.fill")
            }
            .buttonStyle(MangaActionButtonStyle(selected: bookmarked))
            .simultaneousGesture(
                // on long hold, show category select
                LongPressGesture()
                    .onEnded { _ in
                        if bookmarked && hasCategories {
                            longHeldBookmark = true
                            path.present(
                                UINavigationController(
                                    rootViewController: CategorySelectViewController(
                                        manga: manga
                                    )
                                )
                            )
                        }
                    }
            )
            .alert(NSLocalizedString("REMOVE_FROM_LIBRARY_CONFIRM"), isPresented: $showLibraryRemoveConfirm) {
                Button(NSLocalizedString("CANCEL"), role: .cancel) {}
                Button(NSLocalizedString("REMOVE"), role: .destructive) {
                    guard bookmarked else { return }
                    Task {
                        await toggleBookmarked()
                    }
                }
            } message: {
                Text(NSLocalizedString("REMOVE_FROM_LIBRARY_CONFIRM_TEXT"))
            }

            if hasAvailableTrackers {
                Button {
                    onTrackerButtonPressed?()
                } label: {
                    Image(systemName: "clock.arrow.2.circlepath")
                }
                .buttonStyle(MangaActionButtonStyle(selected: isTracking))
            }

            if let url = manga.url {
                MediaDetailsSourceButton(url: url, path: path)
            }
        }
    }

    func toggleBookmarked() async {
        let mangaId = manga.identifier
        let inLibrary = await CoreDataManager.shared.container.performBackgroundTask { context in
            CoreDataManager.shared.hasLibraryManga(
                mangaId: mangaId,
                context: context
            )
        }
        if inLibrary {
            // remove from library
            await MangaManager.shared.removeFromLibrary(mangaId: mangaId)
            bookmarked = false
        } else {
            if await MangaManager.shouldAskForCategories() { // open category select view
                let viewController = UINavigationController(rootViewController: CategorySelectViewController(manga: manga))
                path.present(viewController)
            } else { // add to library
                bookmarked = true
                await MangaManager.shared.addToLibrary(
                    manga: manga,
                    chapters: manga.chapters ?? []
                )
            }
        }
    }

    func updateReadButtonText() {
        var title = ""
        if allChaptersLocked {
            title = NSLocalizedString("ALL_CHAPTERS_LOCKED")
            readButtonDisabled = true
        } else if allChaptersRead {
            title = NSLocalizedString("ALL_CHAPTERS_READ")
            readButtonDisabled = true
        } else if source == nil {
            title = NSLocalizedString("UNAVAILABLE")
            readButtonDisabled = true
        } else {
            if let chapter = nextChapter {
                if !readingInProgress {
                    title = NSLocalizedString("START_READING")
                } else {
                    title = NSLocalizedString("CONTINUE_READING")
                }
                switch chapterTitleDisplayMode {
                    case .volume:
                        if let volumeNum = chapter.volumeNumber {
                            title += " " + String(format: NSLocalizedString("VOL_X"), volumeNum)
                        } else if let chapterNum = chapter.chapterNumber {
                            // Force display as volume if no volume number
                            title += " " + String(format: NSLocalizedString("VOL_X"), chapterNum)
                        }
                    case .chapter:
                        if let chapterNum = chapter.chapterNumber {
                            title += " " + String(format: NSLocalizedString("CH_X"), chapterNum)
                        } else if let volumeNum = chapter.volumeNumber {
                            // Force display as chapter if no chapter number
                            title += " " + String(format: NSLocalizedString("CH_X"), volumeNum)
                        }
                    case .default:
                        if let volumeNum = chapter.volumeNumber {
                            title += " " + String(format: NSLocalizedString("VOL_X"), volumeNum)
                        }
                        if let chapterNum = chapter.chapterNumber {
                            title += " " + String(format: NSLocalizedString("CH_X"), chapterNum)
                        }
                }
            } else {
                title = NSLocalizedString("NO_CHAPTERS_AVAILABLE")
            }
            readButtonDisabled = false
        }
        readButtonText = title
    }
}

struct LabelView: View {
    let text: String
    var background = Color(UIColor.tertiarySystemFill)

    var body: some View {
        Text(text)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .font(.caption2)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct MangaActionButtonStyle: ButtonStyle {
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
//        Group {
//            if selected {
//                configuration.label
//                    .foregroundStyle(.white)
//            } else {
//                configuration.label
//                    .foregroundStyle(.tint)
//            }
//        }
        configuration.label
            .foregroundStyle(selected ? Color.white : Color.accentColor)
            .opacity(configuration.isPressed ? 0.4 : 1)
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 40, height: 32)
            .background(selected ? Color.accentColor : Color(UIColor.secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview {
    @Previewable @State var bookmarked = false
    @Previewable @State var chapterSortOption = ChapterSortOption.sourceOrder
    @Previewable @State var chapterSortAscending = false

    @Previewable @State var filters: [ChapterFilterOption] = []
    @Previewable @State var langFilter: String?
    @Previewable @State var scanlatorFilter: [String] = []
    @Previewable @State var chapterTitleDisplayMode = ChapterTitleDisplayMode.default
    @Previewable @Namespace var transitionNamespace

    MangaDetailsHeaderView(
        source: Binding.constant(AidokuRunner.Source.demo()),
        manga: Binding.constant(AidokuRunner.Manga(
            sourceKey: "",
            key: "",
            title: "Manga",
            authors: ["Author"],
            description: "Description"
        )),
        chapters: Binding.constant([]),
        nextChapter: Binding.constant(nil),
        readingInProgress: Binding.constant(false),
        allChaptersLocked: Binding.constant(false),
        allChaptersRead: Binding.constant(false),
        initialDataLoaded: Binding.constant(true),
        bookmarked: $bookmarked,
        hasCategories: Binding.constant(false),
        coverPressed: Binding.constant(false),
        chapterSortOption: $chapterSortOption,
        chapterSortAscending: $chapterSortAscending,
        filters: $filters,
        langFilter: $langFilter,
        scanlatorFilter: $scanlatorFilter,
        descriptionExpanded: Binding.constant(false),
        chapterTitleDisplayMode: $chapterTitleDisplayMode,
        hasOtherDownloads: false,
        transitionNamespace: transitionNamespace,
    )
}
