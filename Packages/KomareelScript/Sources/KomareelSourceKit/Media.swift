import Foundation

public struct Manga: Sendable, Codable, Hashable {
    public var sourceKey: String
    public var key: String
    public var title: String
    public var cover: String?
    public var artists: [String]?
    public var authors: [String]?
    public var description: String?
    public var url: URL?
    public var tags: [String]?
    public var status: PublishingStatus
    public var contentRating: ContentRating
    public var viewer: Viewer
    public var updateStrategy: UpdateStrategy
    public var nextUpdateTime: Int?
    public var chapters: [Chapter]?

    public init(
        sourceKey: String,
        key: String,
        title: String,
        cover: String? = nil,
        artists: [String]? = nil,
        authors: [String]? = nil,
        description: String? = nil,
        url: URL? = nil,
        tags: [String]? = nil,
        status: PublishingStatus = .unknown,
        contentRating: ContentRating = .unknown,
        viewer: Viewer = .unknown,
        updateStrategy: UpdateStrategy = .always,
        nextUpdateTime: Int? = nil,
        chapters: [Chapter]? = nil
    ) {
        self.sourceKey = sourceKey
        self.key = key
        self.title = title
        self.cover = cover
        self.artists = artists
        self.authors = authors
        self.description = description
        self.url = url
        self.tags = tags
        self.status = status
        self.contentRating = contentRating
        self.viewer = viewer
        self.updateStrategy = updateStrategy
        self.nextUpdateTime = nextUpdateTime
        self.chapters = chapters
    }

    private enum CodingKeys: String, CodingKey {
        case sourceKey
        case key
        case title
        case cover
        case artists
        case authors
        case description
        case url
        case tags
        case status
        case contentRating
        case viewer
        case updateStrategy
        case nextUpdateTime
        case chapters
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        sourceKey = try fields.decodeIfPresent(String.self, forKey: .sourceKey) ?? ""
        key = try fields.decode(String.self, forKey: .key)
        title = try fields.decode(String.self, forKey: .title)
        cover = try fields.decodeIfPresent(String.self, forKey: .cover)
        artists = try fields.decodeIfPresent([String].self, forKey: .artists)
        authors = try fields.decodeIfPresent([String].self, forKey: .authors)
        description = try fields.decodeIfPresent(String.self, forKey: .description)
        url = try fields.decodeIfPresent(URL.self, forKey: .url)
        tags = try fields.decodeIfPresent([String].self, forKey: .tags)
        status = try fields.decodeIfPresent(PublishingStatus.self, forKey: .status) ?? .unknown
        contentRating = try fields.decodeIfPresent(ContentRating.self, forKey: .contentRating) ?? .unknown
        viewer = try fields.decodeIfPresent(Viewer.self, forKey: .viewer) ?? .unknown
        updateStrategy = try fields.decodeIfPresent(UpdateStrategy.self, forKey: .updateStrategy) ?? .always
        nextUpdateTime = try fields.decodeIfPresent(Int.self, forKey: .nextUpdateTime)
        chapters = try fields.decodeIfPresent([Chapter].self, forKey: .chapters)
    }
}

public struct Chapter: Sendable, Codable, Hashable, Identifiable {
    public var id: String { key }
    public var key: String
    public var title: String?
    public var chapterNumber: Float?
    public var volumeNumber: Float?
    public var dateUploaded: Date?
    public var scanlators: [String]?
    public var url: URL?
    public var language: String?
    public var thumbnail: String?
    public var locked: Bool

    public init(
        key: String,
        title: String? = nil,
        chapterNumber: Float? = nil,
        volumeNumber: Float? = nil,
        dateUploaded: Date? = nil,
        scanlators: [String]? = nil,
        url: URL? = nil,
        language: String? = nil,
        thumbnail: String? = nil,
        locked: Bool = false
    ) {
        self.key = key
        self.title = title
        self.chapterNumber = chapterNumber
        self.volumeNumber = volumeNumber
        self.dateUploaded = dateUploaded
        self.scanlators = scanlators
        self.url = url
        self.language = language
        self.thumbnail = thumbnail
        self.locked = locked
    }

    private enum CodingKeys: String, CodingKey {
        case key
        case title
        case chapterNumber
        case volumeNumber
        case dateUploaded
        case scanlators
        case url
        case language
        case thumbnail
        case locked
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        key = try fields.decode(String.self, forKey: .key)
        title = try fields.decodeIfPresent(String.self, forKey: .title)
        chapterNumber = try fields.decodeIfPresent(Float.self, forKey: .chapterNumber)
        volumeNumber = try fields.decodeIfPresent(Float.self, forKey: .volumeNumber)
        dateUploaded = try fields.decodeIfPresent(Double.self, forKey: .dateUploaded)
            .map(Date.init(timeIntervalSince1970:))
        scanlators = try fields.decodeIfPresent([String].self, forKey: .scanlators)
        url = try fields.decodeIfPresent(URL.self, forKey: .url)
        language = try fields.decodeIfPresent(String.self, forKey: .language)
        thumbnail = try fields.decodeIfPresent(String.self, forKey: .thumbnail)
        locked = try fields.decodeIfPresent(Bool.self, forKey: .locked) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(key, forKey: .key)
        try fields.encodeIfPresent(title, forKey: .title)
        try fields.encodeIfPresent(chapterNumber, forKey: .chapterNumber)
        try fields.encodeIfPresent(volumeNumber, forKey: .volumeNumber)
        try fields.encodeIfPresent(dateUploaded?.timeIntervalSince1970, forKey: .dateUploaded)
        try fields.encodeIfPresent(scanlators, forKey: .scanlators)
        try fields.encodeIfPresent(url, forKey: .url)
        try fields.encodeIfPresent(language, forKey: .language)
        try fields.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try fields.encode(locked, forKey: .locked)
    }
}

public struct MangaWithChapter: Sendable, Codable, Hashable {
    public var manga: Manga
    public var chapter: Chapter

    public init(
        manga: Manga,
        chapter: Chapter
    ) {
        self.manga = manga
        self.chapter = chapter
    }
}

public struct MangaPageResult: Sendable, Codable {
    public var entries: [Manga]
    public var hasNextPage: Bool

    public init(
        entries: [Manga],
        hasNextPage: Bool
    ) {
        self.entries = entries
        self.hasNextPage = hasNextPage
    }
}


public enum PublishingStatus: UInt8, Sendable, Codable, CaseIterable {
    case unknown, ongoing, completed, cancelled, hiatus
}

public enum ContentRating: UInt8, Sendable, Codable, CaseIterable {
    case unknown, safe, suggestive, nsfw
}

public enum Viewer: UInt8, Sendable, Codable, CaseIterable {
    case unknown, leftToRight, rightToLeft, vertical, webtoon
}

public enum UpdateStrategy: UInt8, Sendable, Codable {
    case always, never
}

public extension Manga {
    func copy(from value: Manga) -> Manga {
        var result = self
        if !value.sourceKey.isEmpty { result.sourceKey = value.sourceKey }
        if !value.key.isEmpty { result.key = value.key }
        if !value.title.isEmpty { result.title = value.title }
        result.cover = value.cover ?? cover
        result.artists = value.artists ?? artists
        result.authors = value.authors ?? authors
        result.description = value.description ?? description
        result.url = value.url ?? url
        result.tags = value.tags ?? tags
        result.status = value.status
        result.contentRating = value.contentRating
        result.viewer = value.viewer
        result.updateStrategy = value.updateStrategy
        result.nextUpdateTime = value.nextUpdateTime ?? nextUpdateTime
        result.chapters = value.chapters ?? chapters
        return result
    }

    func intoLink() -> HomeComponent.Value.Link {
        .init(title: title, imageUrl: cover, subtitle: authors?.joined(separator: ", ") ?? description, value: .manga(self))
    }
}
