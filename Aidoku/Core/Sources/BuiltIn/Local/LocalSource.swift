//
//  LocalSource.swift
//  Aidoku
//
//  Created by Skitty on 6/5/25.
//

import KomareelSourceKit
import Foundation

extension KomareelSourceKit.Source {
    static func local() -> KomareelSourceKit.Source {
        .init(
            url: nil,
            key: LocalSourceRunner.sourceKey,
            name: NSLocalizedString("LOCAL_FILES"),
            version: 1,
            languages: ["multi"],
            urls: [],
            contentRating: .safe,
            config: .init(
                languageSelectType: .single
            ),
            staticListings: [],
            staticFilters: [],
            staticSettings: [],
            runner: LocalSourceRunner()
        )
    }
}

final class LocalSourceRunner: KomareelSourceKit.Runner {
    static let sourceKey = "local"

    let features = KomareelSourceKit.SourceFeatures(
        providesListings: true,
        providesHome: false, // todo
        dynamicFilters: false,
        dynamicSettings: false,
        dynamicListings: false,
        processesPages: false,
        providesImageRequests: false,
        providesPageDescriptions: false,
        providesAlternateCovers: false,
        providesBaseUrl: false,
        handlesNotifications: false,
        handlesDeepLinks: false,
        handlesBasicLogin: false,
        handlesWebLogin: false
    )

    func getSearchMangaList(query: String?, page: Int, filters: [KomareelSourceKit.FilterValue]) async throws -> KomareelSourceKit.MangaPageResult {
        await LocalFileManager.shared.scanLocalFiles()
        let manga = await LocalFileDataManager.shared.fetchLocalSeries(query: query)
        return .init(entries: manga, hasNextPage: false)
    }

    func getMangaUpdate(manga: KomareelSourceKit.Manga, needsDetails: Bool, needsChapters: Bool) async throws -> KomareelSourceKit.Manga {
        var manga = manga
        if needsDetails {}
        if needsChapters {
            manga.chapters = await LocalFileDataManager.shared.fetchChapters(mangaId: manga.key)
        }
        return manga
    }

    func getPageList(manga: KomareelSourceKit.Manga, chapter: KomareelSourceKit.Chapter) async throws -> [KomareelSourceKit.Page] {
        await LocalFileManager.shared.fetchPages(mangaId: manga.key, chapterId: chapter.key)
    }

    func getMangaList(listing: KomareelSourceKit.Listing, page: Int) async throws -> KomareelSourceKit.MangaPageResult {
        let manga = await LocalFileDataManager.shared.fetchLocalSeries()
        return .init(entries: manga, hasNextPage: false)
    }
}
