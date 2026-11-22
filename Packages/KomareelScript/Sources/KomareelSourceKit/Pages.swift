import Foundation

public struct Page: Sendable, Hashable {
    public var content: PageContent
    public var thumbnail: URL?
    public var hasDescription: Bool
    public var description: String?

    public init(
        content: PageContent,
        thumbnail: URL? = nil,
        hasDescription: Bool = false,
        description: String? = nil
    ) {
        self.content = content
        self.thumbnail = thumbnail
        self.hasDescription = hasDescription
        self.description = description
    }
}

public struct Request: Sendable, Codable {
    public var url: URL?
    public var headers: [String: String]

    public init(
        url: URL?,
        headers: [String: String]
    ) {
        self.url = url
        self.headers = headers
    }
}

public struct Response: Sendable, Codable {
    public var code: Int
    public var headers: [String: String]
    public var request: Request
    public var image: Int32?

    public init(
        code: Int,
        headers: [String: String],
        request: Request,
        image: Int32?
    ) {
        self.code = code
        self.headers = headers
        self.request = request
        self.image = image
    }
}


public typealias PageContext = [String: String]

public enum PageContent: Sendable, Hashable {
    case url(url: URL, context: PageContext? = nil)
    case text(String)
    case image(PlatformImage)
    case zipFile(url: URL, filePath: String)
}
