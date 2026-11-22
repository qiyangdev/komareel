import Foundation

public struct Filter: Codable, Hashable, Sendable {
    public var id: String
    public var title: String?
    public var hideFromHeader: Bool?
    public var value: Value

    public init(id: String, title: String? = nil, hideFromHeader: Bool? = nil, value: Value) {
        self.id = id
        self.title = title
        self.hideFromHeader = hideFromHeader
        self.value = value
    }

    public enum Value: Hashable, Sendable {
        case text(placeholder: String?)
        case sort(canAscend: Bool = true, options: [String], defaultValue: SortDefault?)
        case check(name: String?, canExclude: Bool = false, defaultValue: Bool?)
        case select(SelectFilter)
        case multiselect(MultiSelectFilter)
        case note(String)
        case range(min: Float?, max: Float?, decimal: Bool = false)
    }

    public struct SortDefault: Codable, Hashable, Sendable {
        public let index: Int
        public let ascending: Bool

        public init(index: Int, ascending: Bool) {
            self.index = index
            self.ascending = ascending
        }

        private enum CodingKeys: String, CodingKey { case index, ascending }

        public init(from decoder: Decoder) throws {
            let fields = try decoder.container(keyedBy: CodingKeys.self)
            index = try fields.decode(Int.self, forKey: .index)
            ascending = try fields.decodeIfPresent(Bool.self, forKey: .ascending) ?? false
        }
    }

    private enum Field: String, CodingKey {
        case type, id, title, hideFromHeader, placeholder, canAscend, options, name, canExclude, text, min, max, decimal
        case defaultValue = "default"
    }

    public init(from decoder: Decoder) throws {
        let f = try decoder.container(keyedBy: Field.self)
        let type = try f.decode(String.self, forKey: .type)
        let value: Value = try switch type {
            case "text": .text(placeholder: f.decodeIfPresent(String.self, forKey: .placeholder))
            case "sort": .sort(canAscend: f.decodeIfPresent(Bool.self, forKey: .canAscend) ?? true,
                               options: f.decode([String].self, forKey: .options),
                               defaultValue: f.decodeIfPresent(SortDefault.self, forKey: .defaultValue))
            case "check": .check(name: f.decodeIfPresent(String.self, forKey: .name),
                                 canExclude: f.decodeIfPresent(Bool.self, forKey: .canExclude) ?? false,
                                 defaultValue: f.decodeIfPresent(Bool.self, forKey: .defaultValue))
            case "select": .select(SelectFilter(from: decoder))
            case "multiselect", "multi-select": .multiselect(MultiSelectFilter(from: decoder))
            case "note": .note(f.decode(String.self, forKey: .text))
            case "range": .range(min: f.decodeIfPresent(Float.self, forKey: .min), max: f.decodeIfPresent(Float.self, forKey: .max),
                                 decimal: f.decodeIfPresent(Bool.self, forKey: .decimal) ?? false)
            default: throw DecodingError.dataCorruptedError(forKey: .type, in: f, debugDescription: "Unsupported filter")
        }
        self.init(
            id: try f.decode(String.self, forKey: .id), title: try f.decodeIfPresent(String.self, forKey: .title),
            hideFromHeader: try f.decodeIfPresent(Bool.self, forKey: .hideFromHeader), value: value
        )
    }

    public func encode(to encoder: Encoder) throws {
        var f = encoder.container(keyedBy: Field.self)
        try f.encode(id, forKey: .id)
        try f.encodeIfPresent(title, forKey: .title)
        try f.encodeIfPresent(hideFromHeader, forKey: .hideFromHeader)
        let type: String
        switch value {
            case let .text(placeholder):
                type = "text"
                try f.encodeIfPresent(placeholder, forKey: .placeholder)
            case let .sort(canAscend, options, initial):
                type = "sort"
                try f.encode(canAscend, forKey: .canAscend)
                try f.encode(options, forKey: .options)
                try f.encodeIfPresent(initial, forKey: .defaultValue)
            case let .check(name, canExclude, initial):
                type = "check"
                try f.encodeIfPresent(name, forKey: .name)
                try f.encode(canExclude, forKey: .canExclude)
                try f.encodeIfPresent(initial, forKey: .defaultValue)
            case let .select(value):
                type = "select"
                try value.encode(to: encoder)
            case let .multiselect(value):
                type = "multiselect"
                try value.encode(to: encoder)
            case let .note(text):
                type = "note"
                try f.encode(text, forKey: .text)
            case let .range(min, max, decimal):
                type = "range"
                try f.encodeIfPresent(min, forKey: .min)
                try f.encodeIfPresent(max, forKey: .max)
                try f.encode(decimal, forKey: .decimal)
        }
        try f.encode(type, forKey: .type)
    }
}

public struct SelectFilter: Codable, Hashable, Sendable {
    public var isGenre: Bool
    public var usesTagStyle: Bool
    public var options: [String]
    public var ids: [String]?
    public var defaultValue: String?

    public init(isGenre: Bool = false, usesTagStyle: Bool = false, options: [String], ids: [String]? = nil, defaultValue: String? = nil) {
        self.isGenre = isGenre
        self.usesTagStyle = usesTagStyle
        self.options = options
        self.ids = ids
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case isGenre, usesTagStyle, options, ids
        case defaultValue = "default"
    }

    public init(from decoder: Decoder) throws {
        let f = try decoder.container(keyedBy: CodingKeys.self)
        isGenre = try f.decodeIfPresent(Bool.self, forKey: .isGenre) ?? false
        usesTagStyle = try f.decodeIfPresent(Bool.self, forKey: .usesTagStyle) ?? false
        options = try f.decode([String].self, forKey: .options)
        ids = try f.decodeIfPresent([String].self, forKey: .ids)
        defaultValue = try f.decodeIfPresent(String.self, forKey: .defaultValue)
    }
}

public struct MultiSelectFilter: Codable, Hashable, Sendable {
    public var isGenre: Bool
    public var canExclude: Bool
    public var usesTagStyle: Bool
    public var options: [String]
    public var ids: [String]?
    public var defaultIncluded: [String]?
    public var defaultExcluded: [String]?

    public init(
        isGenre: Bool = false, canExclude: Bool = false, usesTagStyle: Bool = false, options: [String],
        ids: [String]? = nil, defaultIncluded: [String]? = nil, defaultExcluded: [String]? = nil
    ) {
        self.isGenre = isGenre
        self.canExclude = canExclude
        self.usesTagStyle = usesTagStyle
        self.options = options
        self.ids = ids
        self.defaultIncluded = defaultIncluded
        self.defaultExcluded = defaultExcluded
    }

    private enum CodingKeys: String, CodingKey {
        case isGenre, canExclude, usesTagStyle, options, ids, defaultIncluded, defaultExcluded
    }

    public init(from decoder: Decoder) throws {
        let f = try decoder.container(keyedBy: CodingKeys.self)
        isGenre = try f.decodeIfPresent(Bool.self, forKey: .isGenre) ?? false
        canExclude = try f.decodeIfPresent(Bool.self, forKey: .canExclude) ?? false
        usesTagStyle = try f.decodeIfPresent(Bool.self, forKey: .usesTagStyle) ?? false
        options = try f.decode([String].self, forKey: .options)
        ids = try f.decodeIfPresent([String].self, forKey: .ids)
        defaultIncluded = try f.decodeIfPresent([String].self, forKey: .defaultIncluded)
        defaultExcluded = try f.decodeIfPresent([String].self, forKey: .defaultExcluded)
    }
}

public struct SortFilterValue: Codable, Hashable, Sendable {
    public let id: String
    public let index: Int32
    public let ascending: Bool

    public init(id: String, index: Int, ascending: Bool) {
        self.id = id
        self.index = Int32(clamping: index)
        self.ascending = ascending
    }
}

public enum FilterValue: Codable, Hashable, Sendable {
    case text(id: String, value: String)
    case sort(SortFilterValue)
    case check(id: String, value: Int)
    case select(id: String, value: String)
    case multiselect(id: String, included: [String], excluded: [String])
    case range(id: String, from: Float?, to: Float?)

    public var id: String {
        switch self {
            case let .text(id, _), let .check(id, _), let .select(id, _), let .multiselect(id, _, _), let .range(id, _, _): id
            case let .sort(value): value.id
        }
    }

    private enum Kind: Int, Codable { case text, sort, check, select, multiselect, range }
    private enum Field: String, CodingKey { case type, id, value, index, ascending, included, excluded, from, to }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: Field.self)
        let id = try fields.decode(String.self, forKey: .id)
        self = try switch fields.decode(Kind.self, forKey: .type) {
            case .text: .text(id: id, value: fields.decode(String.self, forKey: .value))
            case .sort: .sort(SortFilterValue(from: decoder))
            case .check: .check(id: id, value: fields.decode(Int.self, forKey: .value))
            case .select: .select(id: id, value: fields.decode(String.self, forKey: .value))
            case .multiselect:
                .multiselect(id: id, included: fields.decode([String].self, forKey: .included), excluded: fields.decode([String].self, forKey: .excluded))
            case .range: .range(id: id, from: fields.decodeIfPresent(Float.self, forKey: .from), to: fields.decodeIfPresent(Float.self, forKey: .to))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: Field.self)
        try fields.encode(id, forKey: .id)
        let kind: Kind
        switch self {
            case let .text(_, value): kind = .text; try fields.encode(value, forKey: .value)
            case let .sort(value):
                kind = .sort
                try fields.encode(value.index, forKey: .index)
                try fields.encode(value.ascending, forKey: .ascending)
            case let .check(_, value): kind = .check; try fields.encode(value, forKey: .value)
            case let .select(_, value): kind = .select; try fields.encode(value, forKey: .value)
            case let .multiselect(_, included, excluded):
                kind = .multiselect
                try fields.encode(included, forKey: .included)
                try fields.encode(excluded, forKey: .excluded)
            case let .range(_, from, to):
                kind = .range
                try fields.encodeIfPresent(from, forKey: .from)
                try fields.encodeIfPresent(to, forKey: .to)
        }
        try fields.encode(kind, forKey: .type)
    }
}
