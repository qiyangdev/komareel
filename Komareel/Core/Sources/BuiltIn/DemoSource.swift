import KomareelSourceKit

extension KomareelSourceKit.Source {
    static func demo() -> KomareelSourceKit.Source {
        .init(
            key: "demo", name: "Demo Source", version: 1, languages: ["en"], contentRating: .safe,
            staticListings: [.init(id: "samples", name: "Samples")], runner: DemoSourceRunner()
        )
    }
}

private struct DemoSourceRunner: Runner {
    let features = SourceFeatures(providesListings: true, providesHome: true)
    private let sample = KomareelSourceKit.Manga(
        sourceKey: "demo", key: "reader-sample", title: "Reader Sample",
        description: "A local example for trying the reader.", updateStrategy: .never
    )

    func getHome() async throws -> Home {
        .init(components: [.init(title: "Samples", value: .mangaList(entries: [sample.intoLink()]))])
    }

    func getMangaList(listing: KomareelSourceKit.Listing, page: Int) async throws -> KomareelSourceKit.MangaPageResult {
        .init(entries: page == 1 ? [sample] : [], hasNextPage: false)
    }

    func getSearchMangaList(query: String?, page: Int, filters: [FilterValue]) async throws -> KomareelSourceKit.MangaPageResult {
        guard page == 1 else { return .init(entries: [], hasNextPage: false) }
        let query = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .init(entries: query.isEmpty || sample.title.localizedCaseInsensitiveContains(query) ? [sample] : [], hasNextPage: false)
    }

    func getMangaUpdate(
        manga: KomareelSourceKit.Manga, needsDetails: Bool, needsChapters: Bool
    ) async throws -> KomareelSourceKit.Manga {
        var result = needsDetails && manga.key == sample.key ? sample : manga
        if needsChapters {
            result.chapters = [.init(key: "sample", title: "Introduction")]
        }
        return result
    }

    func getPageList(manga: KomareelSourceKit.Manga, chapter: KomareelSourceKit.Chapter) async throws -> [KomareelSourceKit.Page] {
        [.init(content: .text("# Reader Sample\n\nThis local chapter is available offline."))]
    }
}
