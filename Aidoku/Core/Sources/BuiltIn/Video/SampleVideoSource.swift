import AidokuRunner
import Foundation

protocol VideoSourceRunner: AidokuRunner.Runner {
    func videoURL(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) async throws -> URL
}

extension AidokuRunner.Source {
    static func sampleVideo() -> AidokuRunner.Source {
        .init(
            url: nil,
            key: SampleVideoSourceRunner.sourceKey,
            name: SampleVideoSourceRunner.name,
            version: 1,
            languages: ["multi"],
            urls: [],
            contentRating: .safe,
            config: .init(languageSelectType: .single),
            staticListings: [.init(id: "samples", name: SampleVideoSourceRunner.name)],
            staticFilters: [],
            staticSettings: [],
            runner: SampleVideoSourceRunner()
        )
    }
}

struct SampleVideoSourceRunner: VideoSourceRunner {
    static let sourceKey = "sample.video"
    static var name: String { String(localized: "Video Samples") }

    let features = AidokuRunner.SourceFeatures(providesListings: true)

    private var catalog: AidokuRunner.Manga {
        .init(
            sourceKey: Self.sourceKey,
            key: "video-samples",
            title: Self.name,
            cover: "https://media.w3.org/2010/05/sintel/poster.png",
            description: String(localized: "Play Apple’s HLS test stream and the Sintel trailer."),
            contentRating: .safe
        )
    }

    private enum Sample: String, CaseIterable {
        case bipbop
        case sintel

        var title: String {
            switch self {
                case .bipbop: "BipBop (HLS)"
                case .sintel: "Sintel Trailer (MP4)"
            }
        }

        var url: String {
            switch self {
                case .bipbop:
                    "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8"
                case .sintel:
                    "https://media.w3.org/2010/05/sintel/trailer.mp4"
            }
        }
    }

    func getSearchMangaList(query: String?, page: Int, filters: [AidokuRunner.FilterValue]) async throws -> AidokuRunner.MangaPageResult {
        let catalog = catalog
        let query = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let matches = query.isEmpty
            || catalog.title.localizedCaseInsensitiveContains(query)
            || Sample.allCases.contains { $0.title.localizedCaseInsensitiveContains(query) }
        return .init(entries: page == 1 && matches ? [catalog] : [], hasNextPage: false)
    }

    func getMangaList(listing: AidokuRunner.Listing, page: Int) async throws -> AidokuRunner.MangaPageResult {
        try await getSearchMangaList(query: nil, page: page, filters: [])
    }

    func getMangaUpdate(manga: AidokuRunner.Manga, needsDetails: Bool, needsChapters: Bool) async throws -> AidokuRunner.Manga {
        let catalog = catalog
        guard manga.key == catalog.key else { throw URLError(.resourceUnavailable) }
        var result = needsDetails ? manga.copy(from: catalog) : manga
        if needsChapters {
            result.chapters = Sample.allCases.map { .init(key: $0.rawValue, title: $0.title) }
        }
        return result
    }

    func getPageList(manga: AidokuRunner.Manga, chapter: AidokuRunner.Chapter) async throws -> [AidokuRunner.Page] {
        throw AidokuRunner.SourceError.unimplemented
    }

    func videoURL(manga: AidokuRunner.Manga, episode: AidokuRunner.Chapter) async throws -> URL {
        guard manga.key == catalog.key, let sample = Sample(rawValue: episode.key), let url = URL(string: sample.url) else {
            throw URLError(.resourceUnavailable)
        }
        return url
    }
}
