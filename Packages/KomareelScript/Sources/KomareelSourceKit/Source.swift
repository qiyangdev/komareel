import Foundation
import WebKit

public final class Source: Sendable, Identifiable {
    public let url: URL?
    public let key: String
    public let name: String
    public let version: Int
    public let languages: [String]
    public let urls: [URL]
    public let contentRating: SourceContentRating
    public let imageUrl: URL?
    public let config: SourceInfo.Configuration?
    public let runner: any Runner
    public let staticSettings: [Setting]

    private let staticListings: [Listing]
    private let staticFilters: [Filter]

    public var id: String { key }
    public var apiVersion: String { "1" }
    public var features: SourceFeatures { runner.features }
    public var hasListings: Bool { features.dynamicListings || !staticListings.isEmpty }
    public var onlySearch: Bool { !hasListings && !features.providesHome }
    public var supportsArtistSearch: Bool { config?.supportsArtistSearch ?? hasTextFilter("artist") }
    public var supportsAuthorSearch: Bool { config?.supportsAuthorSearch ?? hasTextFilter("author") }

    public init(
        url: URL? = nil, key: String, name: String, version: Int, languages: [String] = [], urls: [URL] = [],
        contentRating: SourceContentRating, imageUrl: URL? = nil, config: SourceInfo.Configuration? = nil,
        staticListings: [Listing] = [], staticFilters: [Filter] = [], staticSettings: [Setting] = [], runner: any Runner
    ) {
        self.url = url
        self.key = key
        self.name = name
        self.version = version
        self.languages = languages
        self.urls = urls
        self.contentRating = contentRating
        self.imageUrl = imageUrl
        self.config = config
        self.staticListings = staticListings
        self.staticFilters = staticFilters
        self.runner = runner
        self.staticSettings = Self.options(languages: languages, urls: urls, config: config) + staticSettings
        registerDefaults(self.staticSettings)
    }

    private func hasTextFilter(_ id: String) -> Bool {
        staticFilters.contains {
            guard $0.id == id, case .text = $0.value else { return false }
            return true
        }
    }

    private static func options(languages: [String], urls: [URL], config: SourceConfiguration?) -> [Setting] {
        var groups: [Setting] = []
        if languages.count > 1 {
            let preferred = Set(Locale.preferredLanguages.compactMap { Locale(identifier: $0).language.languageCode?.identifier })
            let selected = languages.filter(preferred.contains)
            let titles = languages.map { Locale.current.localizedString(forIdentifier: $0) ?? $0 }
            let single = config?.languageSelectType == .single
            let key = single ? "language" : "languages"
            let title = single ? "LANGUAGE" : "LANGUAGES"
            let value: Setting.Value = single
                ? .select(.init(values: languages, titles: titles, defaultValue: selected.first))
                : .multiselect(.init(values: languages, titles: titles, defaultValue: selected))
            let row = Setting(key: key, title: title, notification: key, refreshes: ["content"], value: value)
            groups.append(.init(title: title, value: .group(.init(items: [row]))))
        }
        if config?.allowsBaseUrlSelect == true, urls.count > 1 {
            let values = urls.map(\.absoluteString)
            let row = Setting(key: "url", title: "BASE_URL", refreshes: ["content"], value: .select(.init(values: values)))
            groups.append(.init(title: row.title, value: .group(.init(items: [row]))))
        }
        return groups
    }

    private func registerDefaults(_ settings: [Setting]) {
        for setting in settings {
            if case let .group(group) = setting.value {
                registerDefaults(group.items)
                continue
            }
            if case let .page(page) = setting.value {
                registerDefaults(page.items)
                continue
            }
            let value: Any? = switch setting.value {
                case let .select(option): option.defaultValue ?? option.values.first
                case let .picker(option): option.defaultValue ?? option.values.first
                case let .multiselect(option): option.defaultValue
                case let .toggle(option): option.defaultValue
                case let .segment(option): option.defaultValue
                case let .stepper(option): option.defaultValue
                case let .text(option): option.defaultValue
                case let .editableList(option): option.defaultValue
                default: nil
            }
            if let value, !setting.key.isEmpty { SettingsStore.shared.register(key: "\(key).\(setting.key)", default: value) }
        }
    }

    public func matchingGenreFilter(for tag: String) -> FilterValue? {
        if config?.supportsTagSearch == true { return .select(id: "genre", value: tag) }
        for filter in staticFilters {
            switch filter.value {
                case let .select(option) where option.isGenre:
                    if let index = option.options.firstIndex(of: tag) {
                        let ids = option.ids ?? option.options
                        if ids.indices.contains(index) { return .select(id: filter.id, value: ids[index]) }
                    }
                case let .multiselect(option) where option.isGenre:
                    if let index = option.options.firstIndex(of: tag) {
                        let ids = option.ids ?? option.options
                        if ids.indices.contains(index) { return .multiselect(id: filter.id, included: [ids[index]], excluded: []) }
                    }
                default: break
            }
        }
        return nil
    }

    public func clearCache() async {
        await WKWebsiteDataStore.forSource(key: key).clearRecords()
    }

    public func getSearchMangaList(query: String?, page: Int, filters: [FilterValue]) async throws -> MangaPageResult {
        try await identified(runner.getSearchMangaList(query: query, page: page, filters: filters))
    }

    public func getMangaList(listing: Listing, page: Int) async throws -> MangaPageResult {
        try await identified(runner.getMangaList(listing: listing, page: page))
    }

    private func identified(_ page: MangaPageResult) -> MangaPageResult {
        var page = page
        for index in page.entries.indices {
            page.entries[index].sourceKey = key
        }
        return page
    }

    public func identify(_ manga: Manga) -> Manga {
        var result = manga
        result.sourceKey = key
        if languages.count == 1, let language = languages.first, var chapters = result.chapters {
            for index in chapters.indices where chapters[index].language == nil {
                chapters[index].language = language
            }
            result.chapters = chapters
        }
        return result
    }

    public func getMangaUpdate(
        manga: Manga, needsDetails: Bool, needsChapters: Bool, onProgress: SourceProgress<Manga>? = nil
    ) async throws -> Manga {
        if let runner = runner as? any ProgressiveRunner {
            let callback = onProgress.map { progress in
                { @MainActor @Sendable (value: Manga) in progress(self.identify(value)) }
            }
            return try await identify(runner.getMangaUpdate(
                manga: manga, needsDetails: needsDetails, needsChapters: needsChapters, onProgress: callback
            ))
        }
        return try await identify(runner.getMangaUpdate(manga: manga, needsDetails: needsDetails, needsChapters: needsChapters))
    }

    public func identify(_ home: Home) -> Home {
        var result = home
        result.assignSource(key)
        return result
    }

    public func getHome(onProgress: SourceProgress<Home>? = nil) async throws -> Home {
        if let runner = runner as? any ProgressiveRunner {
            let callback = onProgress.map { progress in
                { @MainActor @Sendable (value: Home) in progress(self.identify(value)) }
            }
            return try await identify(runner.getHome(onProgress: callback))
        }
        return try await identify(runner.getHome())
    }
    public func getPageList(manga: Manga, chapter: Chapter) async throws -> [Page] {
        try await runner.getPageList(manga: manga, chapter: chapter)
    }

    public func getListings() async throws -> [Listing] {
        features.dynamicListings ? try await staticListings + runner.getListings() : staticListings
    }

    public func getSearchFilters() async throws -> [Filter] {
        features.dynamicFilters ? try await staticFilters + runner.getSearchFilters() : staticFilters
    }

    public func getSettings() async throws -> [Setting] {
        guard features.dynamicSettings else { return staticSettings }
        let dynamic = try await runner.getSettings()
        registerDefaults(dynamic)
        return staticSettings + dynamic
    }

    public func processPageImage(response: Response, context: PageContext?) async throws -> PlatformImage? {
        try await runner.processPageImage(response: response, context: context)
    }

    public func processCoverImage(response: Response) async throws -> PlatformImage? {
        try await runner.processCoverImage(response: response)
    }

    public func getImageRequest(url: String, context: PageContext?) async throws -> URLRequest {
        try await runner.getImageRequest(url: url, context: context)
    }

    public func getPageDescription(page: Page) async throws -> String? {
        if let value = page.description { return value }
        return try await runner.getPageDescription(page: page)
    }

    public func getAlternateCovers(manga: Manga) async throws -> [String] {
        try await runner.getAlternateCovers(manga: manga)
    }

    public func getBaseUrl() async throws -> URL? { try await runner.getBaseUrl() }
    public func handleNotification(notification: String) async throws {
        try await runner.handleNotification(notification: notification)
    }

    public func handleDeepLink(url: String) async throws -> DeepLinkResult? { try await runner.handleDeepLink(url: url) }
    public func handleBasicLogin(key: String, username: String, password: String) async throws -> Bool {
        try await runner.handleBasicLogin(key: key, username: username, password: password)
    }

    public func handleWebLogin(key: String, cookies: [String: String]) async throws -> Bool {
        try await runner.handleWebLogin(key: key, cookies: cookies)
    }

    public func handleMigration(kind: KeyKind, mangaKey: String, chapterKey: String?) async throws -> String? {
        guard features.handlesMigration else { return nil }
        return try await runner.handleMigration(kind: kind, mangaKey: mangaKey, chapterKey: chapterKey)
    }

    public func store<T: Sendable>(value: T) async throws -> Int32 { try await runner.store(value: value) }
    public func remove(value: Int32) async throws { try await runner.remove(value: value) }
}
