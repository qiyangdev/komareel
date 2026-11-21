import AidokuRunner
import SafariServices
import SwiftUI

struct MediaDetailsHeaderView<Metadata: View, Actions: View>: View {
    let source: AidokuRunner.Source?
    let manga: AidokuRunner.Manga
    let path: NavigationCoordinator
    let bookmarked: Bool
    let transitionNamespace: Namespace.ID
    @Binding var descriptionExpanded: Bool
    let actionTitle: Text
    let actionEnabled: Bool
    let onCoverPressed: () -> Void
    let onTitlePressed: () -> Void
    let onPrimaryAction: () -> Void
    @ViewBuilder let metadata: () -> Metadata
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Button(action: onCoverPressed) {
                        MangaCoverView(source: source, coverImage: manga.cover ?? "", width: 114, height: 171)
                            .id(manga.cover ?? "")
                    }
                    .buttonStyle(DarkOverlayButtonStyle())
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .matchedTransitionSourcePlease(id: manga.identifier, in: transitionNamespace)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)

                    Button(action: onTitlePressed) {
                        Text(manga.title)
                            .lineLimit(4)
                            .font(.system(.title2).weight(.semibold))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.75)
                            .contentTransitionDisabledPlease()
                            .multilineTextAlignment(.leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .tint(.primary)
                    .padding(.bottom, 4)

                    metadata()
                    MediaDetailsLabels(source: source, manga: manga, bookmarked: bookmarked)
                    actions()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 174)
            .padding(.bottom, 14)
            .padding(.horizontal, 20)

            if let description = manga.description, !description.isEmpty {
                ExpandableTextView(text: description, expanded: $descriptionExpanded)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 20)
                    .foregroundStyle(.secondary)
            }

            MediaDetailsTags(source: source, path: path, tags: manga.tags ?? [])

            Button(action: onPrimaryAction) {
                actionTitle
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .padding(11)
            .foregroundStyle(.white)
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
            .allowsHitTesting(actionEnabled)
        }
    }
}

private struct MediaDetailsLabels: View {
    let source: AidokuRunner.Source?
    let manga: AidokuRunner.Manga
    let bookmarked: Bool

    var body: some View {
        if manga.status != .unknown || (manga.contentRating != .unknown && manga.contentRating != .safe) || (bookmarked && source != nil) {
            HStack(spacing: 6) {
                if manga.status != .unknown {
                    LabelView(text: manga.status.title)
                }
                if manga.contentRating != .unknown && manga.contentRating != .safe {
                    LabelView(
                        text: manga.contentRating.title,
                        background: manga.contentRating == .suggestive
                            ? .orange.opacity(0.3)
                            : .red.opacity(0.3)
                    )
                }
                if let source, bookmarked {
                    LabelView(
                        text: source.name,
                        background: Color(red: 0.25, green: 0.55, blue: 1).opacity(0.3)
                    )
                }
            }
            .padding(.bottom, 8)
            .animation(.default, value: manga.status)
            .animation(.default, value: bookmarked)
        }
    }
}

private struct MediaDetailsTags: View {
    let source: AidokuRunner.Source?
    let path: NavigationCoordinator
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tags, id: \.self) { tag in
                        let label = TagView(text: tag)
                        if let source, let filter = source.matchingGenreFilter(for: tag) {
                            Button {
                                let viewController = MangaListViewController(source: source, title: tag)
                                viewController.getEntries = { page in
                                    try await source.getSearchMangaList(query: nil, page: page, filters: [
                                        filter
                                    ])
                                }
                                path.push(viewController)
                            } label: {
                                label
                            }
                        } else {
                            label
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 16)
        }
    }
}

struct MediaDetailsSourceButton: View {
    let url: URL
    let path: NavigationCoordinator

    @State private var linkCopied = false

    var body: some View {
        Button {
            guard url.scheme == "http" || url.scheme == "https" else { return }
            path.present(SFSafariViewController(url: url))
        } label: {
            Image(systemName: "safari")
        }
        .buttonStyle(MangaActionButtonStyle())
        .transition(.opacity)
        .simultaneousGesture(
            LongPressGesture()
                .onEnded { finished in
                    if finished {
                        UIPasteboard.general.string = url.absoluteString
                        linkCopied = true
                    }
                }
        )
        .alert(
            NSLocalizedString("LINK_COPIED"),
            isPresented: $linkCopied
        ) {
            Button(NSLocalizedString("OK"), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("LINK_COPIED_TEXT"))
        }
    }
}

private struct TagView: View {
    let text: String

    var body: some View {
        Text(text)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .textSelection(.enabled)
            .background(Color(UIColor.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 100))
    }
}
