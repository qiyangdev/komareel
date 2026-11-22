import KomareelSourceKit
import CKomareelScript
import Foundation
import libxml2

struct SourceScript: Sendable {
    typealias PartialResult = @Sendable (Data) async throws -> Void
    let key: String
    let code: String

    struct Failure: LocalizedError {
        let errorDescription: String?

        init(_ message: String) {
            errorDescription = message.hasPrefix("Error: ") ? String(message.dropFirst(7)) : message
        }
    }

    private struct Markup: Decodable {
        let text: String
        let expression: String
        let html: Bool
    }

    private struct Cipher: Decodable {
        let ciphertext: String
        let key: String
    }

    private struct Document: Decodable {
        let html: String
        let baseURL: URL
    }

    private struct Request: Decodable {
        let operation: String?
        let url: URL?
        let method: String?
        let headers: [String: String]?
        let body: String?
        let bodyBase64: String?
        let timeout: Double?
    }

    private struct Response: Encodable {
        let url: URL?
        let status: Int
        let headers: [String: String]
        let text: String?
        let base64: String?
    }

    private struct Progress: Decodable {
        let json: String
    }

    static func validate(_ script: String) throws {
        var output: UnsafeMutablePointer<CChar>?
        let code = prelude + script
        let status = code.withCString { kr_script_compile($0, code.utf8.count, &output) }
        defer { free(output) }
        guard status == KRScriptDone else {
            throw Failure(output.map { String(cString: $0) } ?? "Unable to compile the source script.")
        }
    }

    func call<Result: Decodable>(
        _ function: String, arguments: some Encodable, as type: Result.Type, onProgress: PartialResult? = nil
    ) async throws -> Result {
        let name = String(decoding: try JSONEncoder().encode(function), as: UTF8.self)
        let args = String(decoding: try JSONEncoder().encode(arguments), as: UTF8.self)
        let invocation = "(async () => JSON.stringify((await globalThis.source[\(name)](\(args))) ?? null))()"
        let host = Host(key: key)
        let context = Unmanaged.passRetained(host)
        defer { context.release() }
        guard let runtime = kr_script_create(context.toOpaque(), { user, operation, input in
            guard let user, let operation, let input else { return nil }
            let host = Unmanaged<Host>.fromOpaque(user).takeUnretainedValue()
            return host.call(String(cString: operation), input: String(cString: input)).map { strdup($0) } ?? nil
        }) else { throw Failure("Unable to initialize the source script.") }
        defer { kr_script_destroy(runtime) }

        let source = Self.prelude + code
        var output: UnsafeMutablePointer<CChar>?
        var status = source.withCString { kr_script_start(runtime, $0, source.utf8.count, invocation, &output) }
        while true {
            let value = output.map { String(cString: $0) }
            free(output)
            output = nil
            guard let value else { throw Failure("The source script returned no result.") }
            switch status {
                case KRScriptDone:
                    return try JSONDecoder().decode(type, from: Data(value.utf8))
                case KRScriptWaiting:
                    try Task.checkCancellation()
                    let response: String
                    let rejected: Int32
                    do {
                        response = try await performRequest(value, onProgress: onProgress)
                        rejected = 0
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        response = error.localizedDescription
                        rejected = 1
                    }
                    status = kr_script_resume(runtime, response, rejected, &output)
                default:
                    throw Failure(value)
            }
        }
    }

    private func performRequest(_ input: String, onProgress: PartialResult?) async throws -> String {
        let data = Data(input.utf8)
        let decoder = JSONDecoder()
        let specification = try decoder.decode(Request.self, from: data)
        if specification.operation == "publish" {
            guard let onProgress else { throw Failure("This operation does not accept partial results.") }
            let progress = try decoder.decode(Progress.self, from: data)
            try await onProgress(Data(progress.json.utf8))
            return "null"
        }
        if specification.operation == "webView" {
            let page = await ScriptWebPage(source: key)
            return try await page.evaluate(decoder.decode(ScriptWebPage.Input.self, from: data))
        }
        guard let url = specification.url, ["http", "https"].contains(url.scheme ?? ""), url.host != nil else {
            throw URLError(.unsupportedURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = specification.method ?? "GET"
        if let timeout = specification.timeout, timeout.isFinite {
            request.timeoutInterval = min(max(timeout, 1), 60)
        }
        request.allHTTPHeaderFields = specification.headers
        if let bodyBase64 = specification.bodyBase64 {
            guard let body = Data(base64Encoded: bodyBase64) else { throw URLError(.cannotDecodeContentData) }
            request.httpBody = body
        } else {
            request.httpBody = specification.body.map { Data($0.utf8) }
        }

        let (body, response) = try await SourceNetwork.perform(request, sourceId: key)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard body.count <= 4 * 1024 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
        var headers: [String: String] = [:]
        for (name, value) in response.allHeaderFields {
            guard let name = name as? String else { continue }
            headers[name.lowercased()] = String(describing: value)
        }
        let text = String(data: body, encoding: .utf8)
        let result = Response(
            url: response.url, status: response.statusCode, headers: headers, text: text,
            base64: text == nil ? body.base64EncodedString() : nil
        )
        return String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
    }

    private static let prelude = """
    const Komareel = Object.freeze({
      request: async (request) => JSON.parse(await __krRequest(JSON.stringify(request))),
      publish: async (value) => { await __krRequest(JSON.stringify({ operation: "publish", json: JSON.stringify(value) })); },
      webView: async (options) => JSON.parse(await __krRequest(JSON.stringify({ ...options, operation: "webView" }))),
      xpath: (text, expression, html = false) => __krCall("xpath", JSON.stringify({ text, expression, html })),
      md5: (text) => __krCall("md5", JSON.stringify(text)),
      decryptAES256ECB: (ciphertext, key) => __krCall("decryptAES256ECB", JSON.stringify({ ciphertext, key })),
      markdown: (html, baseURL) => __krCall("markdown", JSON.stringify({ html, baseURL })),
      setting: (key) => JSON.parse(__krCall("setting", JSON.stringify(key))),
      setSetting: (key, value) => __krCall("setSetting", JSON.stringify([key, value])),
      log: (value) => __krCall("log", JSON.stringify(String(value)))
    });

    """

    private final class Host {
        private let key: String

        init(key: String) {
            self.key = key
        }

        func call(_ operation: String, input: String) -> String? {
            let data = Data(input.utf8)
            let decoder = JSONDecoder()
            switch operation {
                case "xpath":
                    guard let query = try? decoder.decode(Markup.self, from: data) else { return nil }
                    return xpath(query)
                case "md5":
                    return (try? decoder.decode(String.self, from: data)).map(ScriptTransforms.md5)
                case "decryptAES256ECB":
                    guard let input = try? decoder.decode(Cipher.self, from: data) else { return nil }
                    return ScriptTransforms.decryptAES256ECB(ciphertext: input.ciphertext, key: input.key)
                case "markdown":
                    guard let input = try? decoder.decode(Document.self, from: data) else { return nil }
                    return try? ScriptTransforms.markdown(input.html, baseURL: input.baseURL)
                case "setting":
                    guard let name = try? decoder.decode(String.self, from: data) else { return nil }
                    let value = SettingsStore.shared.object(key: "\(key).\(name)") ?? NSNull()
                    guard let result = try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed) else {
                        return "null"
                    }
                    return String(decoding: result, as: UTF8.self)
                case "setSetting":
                    guard let values = (try? JSONSerialization.jsonObject(with: data)) as? [Any],
                          values.count == 2, let name = values.first as? String
                    else { return nil }
                    let value = values[1]
                    if value is NSNull {
                        SettingsStore.shared.remove(key: "\(key).\(name)")
                    } else {
                        guard PropertyListSerialization.propertyList(value, isValidFor: .binary) else { return nil }
                        SettingsStore.shared.setValue(key: "\(key).\(name)", value: value)
                    }
                    return ""
                case "log":
                    guard let message = try? decoder.decode(String.self, from: data) else { return nil }
                    LogManager.logger.log("[\(key)] \(message.prefix(2048))")
                    return ""
                default:
                    return nil
            }
        }

        private func xpath(_ query: Markup) -> String? {
            guard query.text.utf8.count <= 4 * 1024 * 1024 else { return nil }
            let count = Int32(query.text.utf8.count)
            let htmlOptions = HTML_PARSE_NONET.rawValue | HTML_PARSE_NOERROR.rawValue | HTML_PARSE_NOWARNING.rawValue
            let xmlOptions = XML_PARSE_NONET.rawValue | XML_PARSE_NOERROR.rawValue | XML_PARSE_NOWARNING.rawValue
            let document = query.text.withCString { markup in
                if query.html {
                    return htmlReadMemory(markup, count, nil, "UTF-8", Int32(htmlOptions))
                }
                return xmlReadMemory(markup, count, nil, nil, Int32(xmlOptions))
            }
            guard let document else { return nil }
            defer { xmlFreeDoc(document) }
            guard let context = xmlXPathNewContext(document) else { return nil }
            defer { xmlXPathFreeContext(context) }
            guard let result = query.expression.utf8CString.withUnsafeBufferPointer({ buffer in
                buffer.baseAddress?.withMemoryRebound(to: xmlChar.self, capacity: buffer.count) {
                    xmlXPathEvalExpression($0, context)
                }
            }) else { return nil }
            defer { xmlXPathFreeObject(result) }
            guard let value = xmlXPathCastToString(result) else { return nil }
            defer { xmlFree(value) }
            return String(cString: value)
        }
    }
}
