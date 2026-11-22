import KomareelSourceKit
import Foundation

enum SourceNetwork {
    static func perform(_ originalRequest: URLRequest, sourceId: String) async throws -> (Data, URLResponse) {
        let request = if let url = originalRequest.url {
            await KomareelSourceKit.Source.modify(url: url, request: originalRequest)
        } else {
            originalRequest
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               CloudflareHandler.shared.shouldHandle(response: httpResponse, data: data)
            {
                do {
                    return try await CloudflareHandler.shared.handle(request: request)
                } catch let error as CloudflareHandler.HandleError {
                    LogManager.logger.error("Failed to handle CloudFlare: \(error)")
                }
            }
            return (data, response)
        } catch {
            LogManager.logger.error("Error performing network request for \(sourceId): \(error)")
            throw error
        }
    }
}

enum HttpMethod: Int {
    case GET = 0
    case POST = 1
    case HEAD = 2
    case PUT = 3
    case DELETE = 4
    case PATCH = 5
    case OPTIONS = 6
    case CONNECT = 7
    case TRACE = 8

    var stringValue: String {
        switch self {
            case .GET: "GET"
            case .POST: "POST"
            case .PUT: "PUT"
            case .HEAD: "HEAD"
            case .DELETE: "DELETE"
            case .PATCH: "PATCH"
            case .OPTIONS: "OPTIONS"
            case .CONNECT: "CONNECT"
            case .TRACE: "TRACE"
        }
    }
}
