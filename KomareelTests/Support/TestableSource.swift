//
//  TestableSource.swift
//  Aidoku
//
//  Created by skitty on 8/21/26.
//

import KomareelSourceKit
import Foundation

extension KomareelSourceKit.Source {
    static func test(runner: TestableSourceRunner) -> KomareelSourceKit.Source {
        .init(
            url: nil,
            key: "test",
            name: "Test",
            version: 1,
            languages: ["multi"],
            contentRating: .safe,
            runner: runner
        )
    }
}

actor TestableSourceStorage {
    var nextDescriptor: Int32 = 0
    var processedContexts: [PageContext?] = []

    func getContexts() -> [PageContext?] {
        processedContexts
    }

    func process(_ context: PageContext?) {
        processedContexts.append(context)
    }

    func store() -> Int32 {
        nextDescriptor += 1
        return nextDescriptor
    }
}

final class TestableSourceRunner: KomareelSourceKit.Runner {
    let features: KomareelSourceKit.SourceFeatures = .init(processesPages: true)

    let storage = TestableSourceStorage()

    func getSearchMangaList(query: String?, page: Int, filters: [KomareelSourceKit.FilterValue]) async throws -> KomareelSourceKit.MangaPageResult {
        .init(entries: [], hasNextPage: false)
    }

    func getMangaUpdate(manga: KomareelSourceKit.Manga, needsDetails: Bool, needsChapters: Bool) async throws -> KomareelSourceKit.Manga {
        manga
    }

    func getPageList(manga: KomareelSourceKit.Manga, chapter: KomareelSourceKit.Chapter) async throws -> [KomareelSourceKit.Page] {
        []
    }

    func processPageImage(response: Response, context: PageContext?) async throws -> PlatformImage? {
        await storage.process(context)
        return nil
    }

    func store<T: Sendable>(value _: T) async throws -> Int32 {
        await storage.store()
    }

    func remove(value _: Int32) async throws {
    }
}
