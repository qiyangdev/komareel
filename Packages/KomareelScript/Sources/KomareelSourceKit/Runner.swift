import Foundation

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#else
import AppKit
public typealias PlatformImage = NSImage
#endif

public protocol Runner: Sendable {
    var features: SourceFeatures { get }
    func getSearchMangaList(query: String?, page: Int, filters: [FilterValue]) async throws -> MangaPageResult
    func getMangaUpdate(manga: Manga, needsDetails: Bool, needsChapters: Bool) async throws -> Manga
    func getPageList(manga: Manga, chapter: Chapter) async throws -> [Page]
    func getMangaList(listing: Listing, page: Int) async throws -> MangaPageResult
    func getHome() async throws -> Home
    func processPageImage(response: Response, context: PageContext?) async throws -> PlatformImage?
    func processCoverImage(response: Response) async throws -> PlatformImage?
    func getSearchFilters() async throws -> [Filter]
    func getSettings() async throws -> [Setting]
    func getListings() async throws -> [Listing]
    func getImageRequest(url: String, context: PageContext?) async throws -> URLRequest
    func getPageDescription(page: Page) async throws -> String?
    func getAlternateCovers(manga: Manga) async throws -> [String]
    func getBaseUrl() async throws -> URL?
    func handleNotification(notification: String) async throws
    func handleDeepLink(url: String) async throws -> DeepLinkResult?
    func handleBasicLogin(key: String, username: String, password: String) async throws -> Bool
    func handleWebLogin(key: String, cookies: [String: String]) async throws -> Bool
    func handleMigration(kind: KeyKind, mangaKey: String, chapterKey: String?) async throws -> String
    func store<T: Sendable>(value: T) async throws -> Int32
    func remove(value: Int32) async throws
}

public typealias SourceProgress<Value> = @MainActor @Sendable (Value) -> Void

public protocol ProgressiveRunner: Runner {
    func getHome(onProgress: SourceProgress<Home>?) async throws -> Home
    func getMangaUpdate(
        manga: Manga, needsDetails: Bool, needsChapters: Bool, onProgress: SourceProgress<Manga>?
    ) async throws -> Manga
}

public extension Runner {
    func getMangaList(listing: Listing, page: Int) throws -> MangaPageResult { throw SourceError.unimplemented }
    func getHome() throws -> Home { throw SourceError.unimplemented }
    func processPageImage(response: Response, context: PageContext?) throws -> PlatformImage? { nil }
    func processCoverImage(response: Response) throws -> PlatformImage? { nil }
    func getSearchFilters() throws -> [Filter] { [] }
    func getSettings() throws -> [Setting] { [] }
    func getListings() throws -> [Listing] { [] }
    func getImageRequest(url: String, context: PageContext?) throws -> URLRequest { throw SourceError.unimplemented }
    func getPageDescription(page: Page) throws -> String? { nil }
    func getAlternateCovers(manga: Manga) throws -> [String] { [] }
    func getBaseUrl() throws -> URL? { nil }
    func handleNotification(notification: String) throws {}
    func handleDeepLink(url: String) throws -> DeepLinkResult? { nil }
    func handleBasicLogin(key: String, username: String, password: String) throws -> Bool { true }
    func handleWebLogin(key: String, cookies: [String: String]) throws -> Bool { true }
    func handleMigration(kind: KeyKind, mangaKey: String, chapterKey: String?) throws -> String { throw SourceError.unimplemented }
    func store<T: Sendable>(value: T) throws -> Int32 { throw SourceError.unimplemented }
    func remove(value: Int32) throws {}
}
