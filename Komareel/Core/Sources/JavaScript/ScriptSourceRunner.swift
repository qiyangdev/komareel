import KomareelSourceKit
import Foundation
import UIKit

struct ScriptSourceRunner: ProgressiveRunner {
    private let script: SourceScript
    private let exports: Set<String>
    private let imageProcessorInput: ImageProcessorInput
    private let images = ScriptImages()

    var features: KomareelSourceKit.SourceFeatures {
        .init(
            providesListings: exports.contains("listing"),
            providesHome: exports.contains("home"),
            dynamicFilters: exports.contains("filters"),
            dynamicSettings: exports.contains("settings"),
            dynamicListings: exports.contains("listings"),
            processesPages: exports.contains("processPage"),
            processesCovers: exports.contains("processCover"),
            providesImageRequests: exports.contains("imageRequest"),
            providesPageDescriptions: exports.contains("pageDescription"),
            providesAlternateCovers: exports.contains("alternateCovers"),
            providesBaseUrl: exports.contains("baseURL"),
            handlesNotifications: exports.contains("notification"),
            handlesDeepLinks: exports.contains("deepLink"),
            handlesBasicLogin: exports.contains("basicLogin"),
            handlesWebLogin: exports.contains("webLogin"),
            handlesMigration: exports.contains("migrate")
        )
    }

    private struct Manifest: Decodable {
        let scriptAPI: Int
        let exports: Set<String>?
        let imageProcessorInput: ImageProcessorInput?
    }

    private enum ImageProcessorInput: String, Decodable, Sendable {
        case base64, metadata
    }

    private struct Item: Decodable, Sendable {
        let key: String
        let title: String
        let cover: String?
        let artists: [String]?
        let authors: [String]?
        let description: String?
        let url: URL?
        let tags: [String]?
        let status: KomareelSourceKit.PublishingStatus?
        let contentRating: KomareelSourceKit.ContentRating?
        let viewer: KomareelSourceKit.Viewer?
        let updateStrategy: KomareelSourceKit.UpdateStrategy?
        let nextUpdateTime: Int?

        func asManga(source: String, existing: KomareelSourceKit.Manga? = nil) -> KomareelSourceKit.Manga {
            .init(
                sourceKey: source, key: existing?.key ?? key, title: title.isEmpty ? existing?.title ?? title : title,
                cover: cover ?? existing?.cover, artists: artists ?? existing?.artists, authors: authors ?? existing?.authors,
                description: description ?? existing?.description, url: url ?? existing?.url, tags: tags ?? existing?.tags,
                status: status ?? existing?.status ?? .unknown, contentRating: contentRating ?? existing?.contentRating ?? .unknown,
                viewer: viewer ?? existing?.viewer ?? .unknown, updateStrategy: updateStrategy ?? existing?.updateStrategy ?? .always,
                nextUpdateTime: nextUpdateTime ?? existing?.nextUpdateTime, chapters: existing?.chapters
            )
        }
    }

    private struct ListingResult: Decodable {
        let entries: [Item]
        let hasNextPage: Bool
    }

    private struct SearchInput: Encodable {
        let query: String?
        let page: Int
        let filters: [KomareelSourceKit.FilterValue]
    }

    private struct ListingInput: Encodable {
        let id: String
        let page: Int
    }

    private struct DetailInput: Encodable {
        let manga: KomareelSourceKit.Manga
        let needsDetails: Bool
        let needsChapters: Bool
    }

    private struct DetailResult: Decodable, Sendable {
        let details: Item?
        let chapters: [ScriptChapter]?
    }

    private struct ScriptChapter: Decodable, Sendable {
        let key: String
        let title: String?
        let chapterNumber: Float?
        let volumeNumber: Float?
        let date: Double?
        let scanlators: [String]?
        let url: URL?
        let language: String?
        let thumbnail: String?
        let locked: Bool?

        var chapter: KomareelSourceKit.Chapter {
            .init(
                key: key, title: title, chapterNumber: chapterNumber, volumeNumber: volumeNumber,
                dateUploaded: date.map(Date.init(timeIntervalSince1970:)), scanlators: scanlators, url: url, language: language, thumbnail: thumbnail, locked: locked ?? false
            )
        }
    }

    private struct PageInput: Encodable {
        let manga: KomareelSourceKit.Manga
        let chapter: KomareelSourceKit.Chapter
    }

    private struct ScriptPage: Codable {
        let url: URL?
        let text: String?
        let base64Image: String?
        let zipURL: URL?
        let filePath: String?
        let context: KomareelSourceKit.PageContext?
        let thumbnail: URL?
        let description: String?
        let hasDescription: Bool?

        var page: KomareelSourceKit.Page {
            get throws {
                let content: KomareelSourceKit.PageContent
                if let url {
                    content = .url(url: url, context: context)
                } else if let text {
                    content = .text(text)
                } else if let base64Image, let data = Data(base64Encoded: base64Image), let image = UIImage(data: data) {
                    content = .image(image)
                } else if let zipURL, let filePath {
                    content = .zipFile(url: zipURL, filePath: filePath)
                } else {
                    throw KomareelSourceKit.SourceError.message("The source returned unsupported page content.")
                }
                return .init(content: content, thumbnail: thumbnail, hasDescription: hasDescription ?? false, description: description)
            }
        }

        init(page: KomareelSourceKit.Page) {
            var url: URL?
            var text: String?
            var zipURL: URL?
            var filePath: String?
            var context: KomareelSourceKit.PageContext?
            switch page.content {
                case let .url(value, pageContext):
                    url = value
                    context = pageContext
                case let .text(value):
                    text = value
                case let .zipFile(value, path):
                    zipURL = value
                    filePath = path
                case .image:
                    break
            }
            self.url = url
            self.text = text
            self.zipURL = zipURL
            self.filePath = filePath
            self.context = context
            base64Image = nil
            thumbnail = page.thumbnail
            description = page.description
            hasDescription = page.hasDescription
        }
    }

    private struct ImageInput: Encodable {
        let url: String
        let context: KomareelSourceKit.PageContext?
    }

    private struct ImageResponse: Encodable {
        let response: KomareelSourceKit.Response
        let context: KomareelSourceKit.PageContext?
        let imageBase64: String?
    }

    private enum ImageResult: Decodable {
        case data(String)
        case slices(Int)

        private struct Transform: Decodable {
            let reverseHorizontalSlices: Int
        }

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let data = try? value.decode(String.self) {
                self = .data(data)
            } else {
                self = .slices(try value.decode(Transform.self).reverseHorizontalSlices)
            }
        }
    }

    private struct SourceRequest: Decodable {
        let url: URL
        let method: String?
        let headers: [String: String]?
    }

    private struct Empty: Codable {}

    struct Files {
        let manifest: KomareelSourceKit.SourceInfo
        let settings: [KomareelSourceKit.Setting]
        let filters: [KomareelSourceKit.Filter]
        let runner: ScriptSourceRunner
    }

    static func loadFiles(at directory: URL) throws -> Files {
        let data = try Data(contentsOf: directory.appendingPathComponent("source.json"))
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(Manifest.self, from: data)
        guard manifest.scriptAPI == 1 else { throw KomareelSourceKit.SourceError.message("Unsupported Komareel source API.") }
        let info = try decoder.decode(KomareelSourceKit.SourceInfo.self, from: data)
        let id = info.info.id
        let valid = id.range(of: #"^[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*$"#, options: .regularExpression) != nil
        guard valid, id.utf8.count <= 128 else { throw KomareelSourceKit.SourceError.message("Invalid source identifier.") }

        let entry = directory.appendingPathComponent("main.js")
        let size = try entry.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard size.isRegularFile == true, size.isSymbolicLink == false, let byteCount = size.fileSize,
              (1...1024 * 1024).contains(byteCount)
        else { throw KomareelSourceKit.SourceError.message("Invalid Komareel script entrypoint.") }

        let settingsURL = directory.appendingPathComponent("settings.json")
        let settings = settingsURL.exists ? try decoder.decode([KomareelSourceKit.Setting].self, from: Data(contentsOf: settingsURL)) : []
        let filtersURL = directory.appendingPathComponent("filters.json")
        let filters = filtersURL.exists ? try decoder.decode([KomareelSourceKit.Filter].self, from: Data(contentsOf: filtersURL)) : []
        let code = try String(contentsOf: entry, encoding: .utf8)
        try SourceScript.validate(code)
        let runner = Self(
            script: .init(key: id, code: code), exports: manifest.exports ?? [],
            imageProcessorInput: manifest.imageProcessorInput ?? .base64
        )
        return .init(manifest: info, settings: settings, filters: filters, runner: runner)
    }

    static func makeSource(at directory: URL) throws -> KomareelSourceKit.Source {
        try makeSource(from: loadFiles(at: directory), at: directory)
    }

    static func makeSource(from files: Files, at sourceDirectory: URL) -> KomareelSourceKit.Source {
        let manifest = files.manifest
        let info = manifest.info
        return .init(
            url: sourceDirectory, key: info.id, name: info.name, version: info.version, languages: info.languages,
            urls: (info.urls ?? info.url.map { [$0] } ?? []).compactMap(URL.init(string:)),
            contentRating: info.contentRating ?? .safe,
            imageUrl: sourceDirectory.appendingPathComponent("icon.png"), config: manifest.config,
            staticListings: (manifest.listings ?? []).map(\.listing), staticFilters: files.filters,
            staticSettings: files.settings, runner: files.runner
        )
    }

    func getSearchMangaList(query: String?, page: Int, filters: [KomareelSourceKit.FilterValue]) async throws -> KomareelSourceKit.MangaPageResult {
        try await list("search", input: SearchInput(query: query, page: page, filters: filters))
    }

    func getMangaList(listing: KomareelSourceKit.Listing, page: Int) async throws -> KomareelSourceKit.MangaPageResult {
        guard features.providesListings else { throw KomareelSourceKit.SourceError.unimplemented }
        return try await list("listing", input: ListingInput(id: listing.id, page: page))
    }

    private func list(_ method: String, input: some Encodable) async throws -> KomareelSourceKit.MangaPageResult {
        let result = try await run(method, input, as: ListingResult.self)
        return .init(entries: result.entries.map { $0.asManga(source: script.key) }, hasNextPage: result.hasNextPage)
    }

    func getMangaUpdate(manga: KomareelSourceKit.Manga, needsDetails: Bool, needsChapters: Bool) async throws -> KomareelSourceKit.Manga {
        try await getMangaUpdate(manga: manga, needsDetails: needsDetails, needsChapters: needsChapters, onProgress: nil)
    }

    func getMangaUpdate(
        manga: KomareelSourceKit.Manga, needsDetails: Bool, needsChapters: Bool,
        onProgress: SourceProgress<KomareelSourceKit.Manga>?
    ) async throws -> KomareelSourceKit.Manga {
        let input = DetailInput(manga: manga, needsDetails: needsDetails, needsChapters: needsChapters)
        let store = DetailsProgress(manga: manga, needsDetails: needsDetails, needsChapters: needsChapters)
        let final = try await run("details", input, as: DetailResult?.self) { data in
            let update = try JSONDecoder().decode(DetailResult.self, from: data)
            let manga = await store.apply(update)
            await onProgress?(manga)
        }
        return await store.apply(final)
    }

    func getPageList(manga: KomareelSourceKit.Manga, chapter: KomareelSourceKit.Chapter) async throws -> [KomareelSourceKit.Page] {
        let pages = try await run("pages", PageInput(manga: manga, chapter: chapter), as: [ScriptPage].self)
        return try pages.map { try $0.page }
    }

    func getHome() async throws -> KomareelSourceKit.Home { try await getHome(onProgress: nil) }

    func getHome(onProgress: SourceProgress<KomareelSourceKit.Home>?) async throws -> KomareelSourceKit.Home {
        guard exports.contains("home") else { throw KomareelSourceKit.SourceError.unimplemented }
        let store = HomeProgress()
        let final = try await run("home", Empty(), as: KomareelSourceKit.Home?.self) { data in
            let update = try JSONDecoder().decode(HomeUpdate.self, from: data)
            let home = await store.apply(update)
            await onProgress?(home)
        }
        if let final { return final }
        return await store.home
    }
    func getSearchFilters() async throws -> [KomareelSourceKit.Filter] { try await optional("filters", Empty(), as: [KomareelSourceKit.Filter].self) }
    func getSettings() async throws -> [KomareelSourceKit.Setting] { try await optional("settings", Empty(), as: [KomareelSourceKit.Setting].self) }
    func getListings() async throws -> [KomareelSourceKit.Listing] {
        try await optional("listings", Empty(), as: [KomareelSourceKit.SourceInfo.InfoListing].self).map(\.listing)
    }

    func getImageRequest(url: String, context: KomareelSourceKit.PageContext?) async throws -> URLRequest {
        let result = try await optional("imageRequest", ImageInput(url: url, context: context), as: SourceRequest.self)
        var request = URLRequest(url: result.url)
        request.httpMethod = result.method ?? "GET"
        request.allHTTPHeaderFields = result.headers
        return request
    }

    func processPageImage(response: KomareelSourceKit.Response, context: KomareelSourceKit.PageContext?) async throws -> KomareelSourceKit.PlatformImage? {
        try await processedImage("processPage", response, context)
    }

    func processCoverImage(response: KomareelSourceKit.Response) async throws -> KomareelSourceKit.PlatformImage? {
        try await processedImage("processCover", response, nil)
    }

    private func processedImage(_ method: String, _ response: KomareelSourceKit.Response, _ context: KomareelSourceKit.PageContext?) async throws -> UIImage? {
        let image = if let key = response.image { await images.image(for: key) } else { nil as StoredImage? }
        let bytes = imageProcessorInput == .base64 ? image?.encoded : nil
        let input = ImageResponse(response: response, context: context, imageBase64: bytes?.base64EncodedString())
        let result = try await optional(method, input, as: ImageResult?.self)
        switch result {
            case let .data(encoded):
                return Data(base64Encoded: encoded).flatMap { UIImage(data: $0) }
            case let .slices(count):
                guard let image = image?.decoded else { return nil }
                return ScriptTransforms.reverseHorizontalSlices(image, count: count)
            case nil:
                return nil
        }
    }

    func store<T: Sendable>(value: T) async throws -> Int32 {
        if imageProcessorInput == .metadata, let image = value as? UIImage {
            return try await images.insert(.decoded(image))
        }
        let bytes = (value as? Data) ?? (value as? UIImage)?.pngData()
        guard let bytes, bytes.count <= 12 * 1024 * 1024 else {
            throw KomareelSourceKit.SourceError.message("The image is too large for the source processor.")
        }
        return try await images.insert(.bytes(bytes))
    }

    func remove(value: Int32) async throws {
        await images.remove(value)
    }

    func getPageDescription(page: KomareelSourceKit.Page) async throws -> String? {
        try await optional("pageDescription", ScriptPage(page: page), as: String?.self)
    }

    func getAlternateCovers(manga: KomareelSourceKit.Manga) async throws -> [String] {
        try await optional("alternateCovers", manga, as: [String].self)
    }

    func getBaseUrl() async throws -> URL? { try await optional("baseURL", Empty(), as: URL?.self) }
    func handleNotification(notification: String) async throws {
        _ = try await optional("notification", notification, as: AnyScriptResult.self)
    }

    func handleDeepLink(url: String) async throws -> KomareelSourceKit.DeepLinkResult? {
        try await optional("deepLink", url, as: KomareelSourceKit.DeepLinkResult?.self)
    }

    func handleBasicLogin(key: String, username: String, password: String) async throws -> Bool {
        try await optional("basicLogin", ["key": key, "username": username, "password": password], as: Bool.self)
    }

    private struct WebLogin: Encodable {
        let key: String
        let cookies: [String: String]
    }

    func handleWebLogin(key: String, cookies: [String: String]) async throws -> Bool {
        try await optional("webLogin", WebLogin(key: key, cookies: cookies), as: Bool.self)
    }

    private struct Migration: Encodable {
        let kind: Int
        let mangaKey: String
        let chapterKey: String?
    }

    func handleMigration(kind: KomareelSourceKit.KeyKind, mangaKey: String, chapterKey: String?) async throws -> String {
        try await optional("migrate", Migration(kind: kind.rawValue, mangaKey: mangaKey, chapterKey: chapterKey), as: String.self)
    }

    private func optional<T: Decodable>(_ method: String, _ input: some Encodable, as type: T.Type) async throws -> T {
        guard exports.contains(method) else { throw KomareelSourceKit.SourceError.unimplemented }
        return try await run(method, input, as: type)
    }

    private func run<T: Decodable>(
        _ method: String, _ input: some Encodable, as type: T.Type, onProgress: SourceScript.PartialResult? = nil
    ) async throws -> T {
        do {
            return try await script.call(method, arguments: input, as: type, onProgress: onProgress)
        } catch let error as SourceScript.Failure {
            throw KomareelSourceKit.SourceError.message(error.localizedDescription)
        }
    }

    private struct HomeUpdate: Decodable, Sendable {
        let components: [HomeComponent]?
        let component: HomeComponent?
    }

    private actor HomeProgress {
        var home = KomareelSourceKit.Home(components: [])

        func apply(_ update: HomeUpdate) -> KomareelSourceKit.Home {
            if let components = update.components { home.components = components }
            if let component = update.component { home.components.append(component) }
            return home
        }
    }

    private actor DetailsProgress {
        private var manga: KomareelSourceKit.Manga
        private let needsDetails: Bool
        private let needsChapters: Bool

        init(manga: KomareelSourceKit.Manga, needsDetails: Bool, needsChapters: Bool) {
            self.manga = manga
            self.needsDetails = needsDetails
            self.needsChapters = needsChapters
        }

        func apply(_ result: DetailResult?) -> KomareelSourceKit.Manga {
            if needsDetails, let details = result?.details { manga = details.asManga(source: manga.sourceKey, existing: manga) }
            if needsChapters, let chapters = result?.chapters { manga.chapters = chapters.map(\.chapter) }
            return manga
        }
    }

    private enum StoredImage: Sendable {
        case bytes(Data)
        case decoded(UIImage)

        var encoded: Data? {
            switch self {
                case .bytes(let data): data
                case .decoded(let image): image.pngData()
            }
        }

        var decoded: UIImage? {
            switch self {
                case .bytes(let data): UIImage(data: data)
                case .decoded(let image): image
            }
        }
    }

    private actor ScriptImages {
        private var next: Int32 = 0
        private var images: [Int32: StoredImage] = [:]

        func insert(_ image: StoredImage) throws -> Int32 {
            guard images.count < 16 else { throw KomareelSourceKit.SourceError.message("Too many source images are in progress.") }
            repeat { next &+= 1 } while images[next] != nil
            images[next] = image
            return next
        }

        func image(for key: Int32) -> StoredImage? { images[key] }
        func remove(_ key: Int32) { images.removeValue(forKey: key) }
    }
}

private struct AnyScriptResult: Decodable {
    init(from decoder: Decoder) {}
}
