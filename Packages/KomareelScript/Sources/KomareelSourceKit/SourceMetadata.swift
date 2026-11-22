import Foundation

public struct SourceFeatures: Sendable {
    public var providesListings: Bool
    public var providesHome: Bool
    public var dynamicFilters: Bool
    public var dynamicSettings: Bool
    public var dynamicListings: Bool
    public var processesPages: Bool
    public var processesCovers: Bool
    public var providesImageRequests: Bool
    public var providesPageDescriptions: Bool
    public var providesAlternateCovers: Bool
    public var providesBaseUrl: Bool
    public var handlesNotifications: Bool
    public var handlesDeepLinks: Bool
    public var handlesBasicLogin: Bool
    public var handlesWebLogin: Bool
    public var handlesMigration: Bool

    public init(
        providesListings: Bool = false,
        providesHome: Bool = false,
        dynamicFilters: Bool = false,
        dynamicSettings: Bool = false,
        dynamicListings: Bool = false,
        processesPages: Bool = false,
        processesCovers: Bool = false,
        providesImageRequests: Bool = false,
        providesPageDescriptions: Bool = false,
        providesAlternateCovers: Bool = false,
        providesBaseUrl: Bool = false,
        handlesNotifications: Bool = false,
        handlesDeepLinks: Bool = false,
        handlesBasicLogin: Bool = false,
        handlesWebLogin: Bool = false,
        handlesMigration: Bool = false
    ) {
        self.providesListings = providesListings
        self.providesHome = providesHome
        self.dynamicFilters = dynamicFilters
        self.dynamicSettings = dynamicSettings
        self.dynamicListings = dynamicListings
        self.processesPages = processesPages
        self.processesCovers = processesCovers
        self.providesImageRequests = providesImageRequests
        self.providesPageDescriptions = providesPageDescriptions
        self.providesAlternateCovers = providesAlternateCovers
        self.providesBaseUrl = providesBaseUrl
        self.handlesNotifications = handlesNotifications
        self.handlesDeepLinks = handlesDeepLinks
        self.handlesBasicLogin = handlesBasicLogin
        self.handlesWebLogin = handlesWebLogin
        self.handlesMigration = handlesMigration
    }
}

public struct SourceConfiguration: Sendable, Codable {
    public var languageSelectType: LanguageSelectType?
    public var supportsArtistSearch: Bool?
    public var supportsAuthorSearch: Bool?
    public var supportsTagSearch: Bool?
    public var allowsBaseUrlSelect: Bool?
    public var breakingChangeVersion: Int?
    public var hidesFiltersWhileSearching: Bool?
    public var maximumParallelRequests: Int?

    public init(
        languageSelectType: LanguageSelectType? = nil,
        supportsArtistSearch: Bool? = nil,
        supportsAuthorSearch: Bool? = nil,
        supportsTagSearch: Bool? = nil,
        allowsBaseUrlSelect: Bool? = nil,
        breakingChangeVersion: Int? = nil,
        hidesFiltersWhileSearching: Bool? = nil,
        maximumParallelRequests: Int? = nil
    ) {
        self.languageSelectType = languageSelectType
        self.supportsArtistSearch = supportsArtistSearch
        self.supportsAuthorSearch = supportsAuthorSearch
        self.supportsTagSearch = supportsTagSearch
        self.allowsBaseUrlSelect = allowsBaseUrlSelect
        self.breakingChangeVersion = breakingChangeVersion
        self.hidesFiltersWhileSearching = hidesFiltersWhileSearching
        self.maximumParallelRequests = maximumParallelRequests
    }
}

public struct Listing: Sendable, Codable, Hashable {
    public var id: String
    public var name: String
    public var kind: ListingKind

    public init(
        id: String,
        name: String,
        kind: ListingKind = .default
    ) {
        self.id = id
        self.name = name
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case id, name, kind }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        id = try fields.decode(String.self, forKey: .id)
        name = try fields.decodeIfPresent(String.self, forKey: .name) ?? id
        kind = try fields.decodeIfPresent(ListingKind.self, forKey: .kind) ?? .default
    }
}

public struct DeepLinkResult: Sendable, Codable {
    public var mangaKey: String?
    public var chapterKey: String?
    public var listing: Listing?

    public init(
        mangaKey: String? = nil,
        chapterKey: String? = nil,
        listing: Listing? = nil
    ) {
        self.mangaKey = mangaKey
        self.chapterKey = chapterKey
        self.listing = listing
    }
}


public enum SourceContentRating: Int, Sendable, Codable, CaseIterable {
    case safe, containsNsfw, primarilyNsfw
}

public enum LanguageSelectType: String, Sendable, Codable {
    case single, multiple
}

public enum ListingKind: UInt8, Sendable, Codable {
    case `default`, list
}

public enum KeyKind: Int, Sendable {
    case manga, chapter
}

public enum SourceError: Error, Equatable {
    case missingResult, unimplemented, networkError, message(String)
    case htmlError, jsonParseError, deserializeError
}

public struct SourceInfo: Sendable, Codable {
    public typealias Configuration = SourceConfiguration
    public let info: Info
    public let listings: [InfoListing]?
    public let config: Configuration?

    public struct Info: Sendable, Codable {
        public let id: String
        public let name: String
        public let altNames: [String]?
        public let version: Int
        public let url: String?
        public let urls: [String]?
        public let languages: [String]
        public let contentRating: SourceContentRating?
    }

    public struct InfoListing: Sendable, Codable {
        public let listing: Listing

        public init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let name = try? value.decode(String.self) {
                listing = .init(id: name, name: name)
            } else {
                listing = try value.decode(Listing.self)
            }
        }

        public func encode(to encoder: Encoder) throws {
            var value = encoder.singleValueContainer()
            try value.encode(listing)
        }
    }
}
