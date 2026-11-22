import Foundation

public struct Home: Codable, Hashable, Sendable {
    public var components: [HomeComponent]

    public init(components: [HomeComponent]) {
        self.components = components
    }

    mutating func assignSource(_ key: String) {
        for index in components.indices {
            components[index].value.assignSource(key)
        }
    }
}

public struct HomeComponent: Codable, Hashable, Sendable {
    public var title: String?
    public var subtitle: String?
    public var value: Value

    public init(title: String?, subtitle: String? = nil, value: Value) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }

    public enum Value: Codable, Hashable, Sendable {
        case imageScroller(links: [Link], autoScrollInterval: TimeInterval? = nil, width: Int? = nil, height: Int? = nil)
        case bigScroller(entries: [Manga], autoScrollInterval: TimeInterval? = nil)
        case scroller(entries: [Link], listing: Listing? = nil)
        case mangaList(ranking: Bool = false, pageSize: Int? = nil, entries: [Link], listing: Listing? = nil)
        case mangaChapterList(pageSize: Int? = nil, entries: [MangaWithChapter], listing: Listing? = nil)
        case filters([FilterItem])
        case links([Link])

        public var intValue: Int {
            switch self {
                case .imageScroller: 0
                case .bigScroller: 1
                case .scroller: 2
                case .mangaList: 3
                case .mangaChapterList: 4
                case .filters: 5
                case .links: 6
            }
        }

        public struct FilterItem: Codable, Hashable, Sendable {
            public var title: String
            public var values: [FilterValue]?

            public init(title: String, values: [FilterValue]?) {
                self.title = title
                self.values = values
            }
        }

        public struct Link: Codable, Hashable, Sendable {
            public var title: String
            public var imageUrl: String?
            public var subtitle: String?
            public var value: LinkValue?

            public init(title: String, imageUrl: String? = nil, subtitle: String? = nil, value: LinkValue? = nil) {
                self.title = title
                self.imageUrl = imageUrl
                self.subtitle = subtitle
                self.value = value
            }
        }

        public enum LinkValue: Codable, Hashable, Sendable {
            case url(String)
            case listing(Listing)
            case manga(Manga)
        }

        mutating func assignSource(_ key: String) {
            func manga(_ item: Manga) -> Manga {
                var result = item
                result.sourceKey = key
                return result
            }

            func links(_ entries: [Link]) -> [Link] {
                entries.map { entry in
                    guard case let .manga(item) = entry.value else { return entry }
                    var result = entry
                    result.value = .manga(manga(item))
                    return result
                }
            }

            switch self {
                case let .imageScroller(items, interval, width, height):
                    self = .imageScroller(links: links(items), autoScrollInterval: interval, width: width, height: height)
                case let .bigScroller(items, interval):
                    self = .bigScroller(entries: items.map(manga), autoScrollInterval: interval)
                case let .scroller(items, listing):
                    self = .scroller(entries: links(items), listing: listing)
                case let .mangaList(ranking, pageSize, items, listing):
                    self = .mangaList(ranking: ranking, pageSize: pageSize, entries: links(items), listing: listing)
                case let .mangaChapterList(size, items, listing):
                    let updated = items.map { MangaWithChapter(manga: manga($0.manga), chapter: $0.chapter) }
                    self = .mangaChapterList(pageSize: size, entries: updated, listing: listing)
                case let .links(items):
                    self = .links(links(items))
                case .filters:
                    break
            }
        }
    }
}
