import Foundation

public enum SettingType: String, Codable, Sendable {
    case group
    case select
    case multiselect = "multi-select"
    case toggle = "switch"
    case stepper
    case segment
    case text
    case button
    case link
    case login
    case page
    case editableList = "editable-list"
    case picker
    case custom

    public var requiresKey: Bool {
        ![.group, .button, .link, .page].contains(self)
    }
}

public struct Setting: Sendable, Hashable, Codable {
    public var key: String
    public var title: String
    public var notification: String?
    public var requires: String?
    public var requiresFalse: String?
    public var refreshes: [String]
    public var value: Value

    public init(
        key: String = "",
        title: String = "",
        notification: String? = nil,
        requires: String? = nil,
        requiresFalse: String? = nil,
        refreshes: [String] = [],
        value: Value
    ) {
        self.key = key
        self.title = title
        self.notification = notification
        self.requires = requires
        self.requiresFalse = requiresFalse
        self.refreshes = refreshes
        self.value = value
    }

    public enum Value: Sendable, Hashable {
        case group(GroupSetting)
        case select(SelectSetting)
        case multiselect(MultiSelectSetting)
        case toggle(ToggleSetting)
        case stepper(StepperSetting)
        case segment(SegmentSetting)
        case text(TextSetting)
        case button(ButtonSetting)
        case link(LinkSetting)
        case login(LoginSetting)
        case page(PageSetting)
        case editableList(EditableListSetting)
        case picker(PickerSetting)
        case custom
    }

    public var type: SettingType {
        switch value {
            case .group: .group
            case .select: .select
            case .multiselect: .multiselect
            case .toggle: .toggle
            case .stepper: .stepper
            case .segment: .segment
            case .text: .text
            case .button: .button
            case .link: .link
            case .login: .login
            case .page: .page
            case .editableList: .editableList
            case .picker: .picker
            case .custom: .custom
        }
    }

    private enum Field: String, CodingKey {
        case key, title, notification, requires, requiresFalse, refreshes, type
    }

    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: Field.self)
        let type = try fields.decode(SettingType.self, forKey: .type)
        let value: Value = try switch type {
            case .group: .group(GroupSetting(from: decoder))
            case .select: .select(SelectSetting(from: decoder))
            case .multiselect: .multiselect(MultiSelectSetting(from: decoder))
            case .toggle: .toggle(ToggleSetting(from: decoder))
            case .stepper: .stepper(StepperSetting(from: decoder))
            case .segment: .segment(SegmentSetting(from: decoder))
            case .text: .text(TextSetting(from: decoder))
            case .button: .button(ButtonSetting(from: decoder))
            case .link: .link(LinkSetting(from: decoder))
            case .login: .login(LoginSetting(from: decoder))
            case .page: .page(PageSetting(from: decoder))
            case .editableList: .editableList(EditableListSetting(from: decoder))
            case .picker: .picker(PickerSetting(from: decoder))
            case .custom: .custom
        }
        let key = try fields.decodeIfPresent(String.self, forKey: .key) ?? ""
        if key.isEmpty && type.requiresKey {
            throw DecodingError.keyNotFound(Field.key, .init(codingPath: decoder.codingPath, debugDescription: "Missing setting identifier"))
        }
        self.init(
            key: key,
            title: try fields.decodeIfPresent(String.self, forKey: .title) ?? "",
            notification: try fields.decodeIfPresent(String.self, forKey: .notification),
            requires: try fields.decodeIfPresent(String.self, forKey: .requires),
            requiresFalse: try fields.decodeIfPresent(String.self, forKey: .requiresFalse),
            refreshes: try fields.decodeIfPresent([String].self, forKey: .refreshes) ?? [],
            value: value
        )
    }

    public func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: Field.self)
        try fields.encode(type, forKey: .type)
        try fields.encode(key, forKey: .key)
        try fields.encode(title, forKey: .title)
        try fields.encodeIfPresent(notification, forKey: .notification)
        try fields.encodeIfPresent(requires, forKey: .requires)
        try fields.encodeIfPresent(requiresFalse, forKey: .requiresFalse)
        if !refreshes.isEmpty { try fields.encode(refreshes, forKey: .refreshes) }
        switch value {
            case let .group(value): try value.encode(to: encoder)
            case let .select(value): try value.encode(to: encoder)
            case let .multiselect(value): try value.encode(to: encoder)
            case let .toggle(value): try value.encode(to: encoder)
            case let .stepper(value): try value.encode(to: encoder)
            case let .segment(value): try value.encode(to: encoder)
            case let .text(value): try value.encode(to: encoder)
            case let .button(value): try value.encode(to: encoder)
            case let .link(value): try value.encode(to: encoder)
            case let .login(value): try value.encode(to: encoder)
            case let .page(value): try value.encode(to: encoder)
            case let .editableList(value): try value.encode(to: encoder)
            case let .picker(value): try value.encode(to: encoder)
            case .custom: break
        }
    }
}

public struct GroupSetting: Sendable, Codable, Hashable {
    public var footer: String?
    public var items: [Setting]

    public init(
        footer: String? = nil,
        items: [Setting]
    ) {
        self.footer = footer
        self.items = items
    }
}

public struct SelectSetting: Sendable, Codable, Hashable {
    public var values: [String]
    public var titles: [String]?
    public var authToOpen: Bool?
    public var defaultValue: String?

    public init(
        values: [String],
        titles: [String]? = nil,
        authToOpen: Bool? = nil,
        defaultValue: String? = nil
    ) {
        self.values = values
        self.titles = titles
        self.authToOpen = authToOpen
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case values
        case titles
        case authToOpen
        case defaultValue = "default"
    }
}

public struct MultiSelectSetting: Sendable, Codable, Hashable {
    public var values: [String]
    public var titles: [String]?
    public var authToOpen: Bool?
    public var defaultValue: [String]?

    public init(
        values: [String],
        titles: [String]? = nil,
        authToOpen: Bool? = nil,
        defaultValue: [String]? = nil
    ) {
        self.values = values
        self.titles = titles
        self.authToOpen = authToOpen
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case values
        case titles
        case authToOpen
        case defaultValue = "default"
    }
}

public struct PickerSetting: Sendable, Codable, Hashable {
    public var values: [String]
    public var titles: [String]?
    public var defaultValue: String?

    public init(
        values: [String],
        titles: [String]? = nil,
        defaultValue: String? = nil
    ) {
        self.values = values
        self.titles = titles
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case values
        case titles
        case defaultValue = "default"
    }
}

public struct ToggleSetting: Sendable, Codable, Hashable {
    public var subtitle: String?
    public var authToDisable: Bool?
    public var defaultValue: Bool?

    public init(
        subtitle: String? = nil,
        authToDisable: Bool? = nil,
        defaultValue: Bool? = false
    ) {
        self.subtitle = subtitle
        self.authToDisable = authToDisable
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case subtitle
        case authToDisable
        case defaultValue = "default"
    }
}

public struct StepperSetting: Sendable, Codable, Hashable {
    public var minimumValue: Double
    public var maximumValue: Double
    public var stepValue: Double?
    public var defaultValue: Double?

    public init(
        minimumValue: Double,
        maximumValue: Double,
        stepValue: Double? = nil,
        defaultValue: Double? = nil
    ) {
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.stepValue = stepValue
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case minimumValue
        case maximumValue
        case stepValue
        case defaultValue = "default"
    }
}

public struct SegmentSetting: Sendable, Codable, Hashable {
    public var options: [String]
    public var defaultValue: Int?

    public init(
        options: [String],
        defaultValue: Int? = nil
    ) {
        self.options = options
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case options
        case defaultValue = "default"
    }
}

public struct TextSetting: Sendable, Codable, Hashable {
    public var placeholder: String?
    public var autocapitalizationType: Int?
    public var keyboardType: Int?
    public var returnKeyType: Int?
    public var autocorrectionDisabled: Bool?
    public var secure: Bool?
    public var defaultValue: String?

    public init(
        placeholder: String? = nil,
        autocapitalizationType: Int? = nil,
        keyboardType: Int? = nil,
        returnKeyType: Int? = nil,
        autocorrectionDisabled: Bool? = nil,
        secure: Bool? = nil,
        defaultValue: String? = nil
    ) {
        self.placeholder = placeholder
        self.autocapitalizationType = autocapitalizationType
        self.keyboardType = keyboardType
        self.returnKeyType = returnKeyType
        self.autocorrectionDisabled = autocorrectionDisabled
        self.secure = secure
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case placeholder
        case autocapitalizationType
        case keyboardType
        case returnKeyType
        case autocorrectionDisabled
        case secure
        case defaultValue = "default"
    }
}

public struct ButtonSetting: Sendable, Codable, Hashable {
    public var destructive: Bool?
    public var confirmTitle: String?
    public var confirmText: String?

    public init(
        destructive: Bool? = false,
        confirmTitle: String? = nil,
        confirmText: String? = nil
    ) {
        self.destructive = destructive
        self.confirmTitle = confirmTitle
        self.confirmText = confirmText
    }
}

public struct LinkSetting: Sendable, Codable, Hashable {
    public var url: String
    public var external: Bool?

    public init(
        url: String,
        external: Bool? = nil
    ) {
        self.url = url
        self.external = external
    }
}

public struct LoginSetting: Sendable, Codable, Hashable {
    public var method: Method
    public var url: String?
    public var urlKey: String?
    public var logoutTitle: String?
    public var pkce: Bool?
    public var tokenUrl: String?
    public var callbackScheme: String?
    public var useEmail: Bool?
    public var localStorageKeys: [String]?
    public var clearCookiesOnLogOut: Bool?

    public init(
        method: Method,
        url: String? = nil,
        urlKey: String? = nil,
        logoutTitle: String? = nil,
        pkce: Bool? = false,
        tokenUrl: String? = nil,
        callbackScheme: String? = nil,
        useEmail: Bool? = nil,
        localStorageKeys: [String]? = nil,
        clearCookiesOnLogOut: Bool? = false
    ) {
        self.method = method
        self.url = url
        self.urlKey = urlKey
        self.logoutTitle = logoutTitle
        self.pkce = pkce
        self.tokenUrl = tokenUrl
        self.callbackScheme = callbackScheme
        self.useEmail = useEmail
        self.localStorageKeys = localStorageKeys
        self.clearCookiesOnLogOut = clearCookiesOnLogOut
    }

    public enum Method: String, Sendable, Codable {
        case basic, oauth, web
    }
}

public struct PageSetting: Sendable, Codable, Hashable {
    public var items: [Setting]
    public var inlineTitle: Bool?
    public var authToOpen: Bool?
    public var icon: Icon?
    public var info: String?

    public init(
        items: [Setting],
        inlineTitle: Bool? = false,
        authToOpen: Bool? = false,
        icon: Icon? = nil,
        info: String? = nil
    ) {
        self.items = items
        self.inlineTitle = inlineTitle
        self.authToOpen = authToOpen
        self.icon = icon
        self.info = info
    }

    public enum Icon: Codable, Sendable, Hashable {
        case system(name: String, color: String, inset: Int = 5)
        case url(String)

        private enum Field: String, CodingKey {
            case type, name, color, inset, url
        }

        public init(from decoder: Decoder) throws {
            let fields = try decoder.container(keyedBy: Field.self)
            let type = try fields.decode(String.self, forKey: .type)
            switch type {
                case "system":
                    self = try .system(
                        name: fields.decode(String.self, forKey: .name),
                        color: fields.decode(String.self, forKey: .color),
                        inset: fields.decodeIfPresent(Int.self, forKey: .inset) ?? 5
                    )
                case "url": self = try .url(fields.decode(String.self, forKey: .url))
                default: throw DecodingError.dataCorruptedError(forKey: .type, in: fields, debugDescription: "Unsupported icon")
            }
        }

        public func encode(to encoder: Encoder) throws {
            var fields = encoder.container(keyedBy: Field.self)
            switch self {
                case let .system(name, color, inset):
                    try fields.encode("system", forKey: .type)
                    try fields.encode(name, forKey: .name)
                    try fields.encode(color, forKey: .color)
                    try fields.encode(inset, forKey: .inset)
                case let .url(url):
                    try fields.encode("url", forKey: .type)
                    try fields.encode(url, forKey: .url)
            }
        }
    }
}

public struct EditableListSetting: Sendable, Codable, Hashable {
    public var lineLimit: Int?
    public var inline: Bool?
    public var placeholder: String?
    public var defaultValue: [String]?

    public init(
        lineLimit: Int? = nil,
        inline: Bool? = nil,
        placeholder: String? = nil,
        defaultValue: [String]? = nil
    ) {
        self.lineLimit = lineLimit
        self.inline = inline
        self.placeholder = placeholder
        self.defaultValue = defaultValue
    }

    private enum CodingKeys: String, CodingKey {
        case lineLimit
        case inline
        case placeholder
        case defaultValue = "default"
    }
}
