import KomareelSourceKit
import WebKit

@MainActor
final class ScriptWebPage: NSObject, WKNavigationDelegate {
    struct Input: Decodable {
        let url: URL?
        let html: String?
        let expression: String?
        let contentRules: String?
        let userScripts: [String]?
    }

    private let browser: WKWebView
    private var loadResult: CheckedContinuation<Void, Error>?
    private var loadTimeout: Task<Void, Never>?

    init(source: String) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .forSource(key: source)
        browser = WKWebView(frame: .zero, configuration: config)
        super.init()
        browser.navigationDelegate = self
    }

    func evaluate(_ input: Input) async throws -> String {
        let url = input.url
        if let url, !["http", "https"].contains(url.scheme ?? "") { throw URLError(.unsupportedURL) }
        guard url != nil || input.html != nil else { throw URLError(.badURL) }

        let controller = browser.configuration.userContentController
        if let rules = input.contentRules {
            let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: UUID().uuidString,
                encodedContentRuleList: rules
            )
            if let ruleList { controller.add(ruleList) }
        }
        for script in input.userScripts ?? [] {
            controller.addUserScript(.init(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                loadResult = continuation
                loadTimeout = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 20_000_000_000)
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(URLError(.timedOut)))
                }
                let navigation: WKNavigation? = if let html = input.html {
                    browser.loadHTMLString(html, baseURL: url)
                } else if let url {
                    browser.load(URLRequest(url: url))
                } else {
                    nil
                }
                if navigation == nil { finish(.failure(URLError(.badURL))) }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(CancellationError()))
            }
        }
        try Task.checkCancellation()

        let expression = input.expression ?? "document.documentElement.outerHTML"
        let output = try await browser.callAsyncJavaScript(
            "return JSON.stringify((await (\(expression))) ?? null);",
            arguments: [:], in: nil, contentWorld: .defaultClient
        )
        guard let output = output as? String else { throw URLError(.cannotDecodeContentData) }
        return output
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(.failure(URLError(.networkConnectionLost)))
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation = loadResult else { return }
        loadResult = nil
        loadTimeout?.cancel()
        loadTimeout = nil
        if case .failure = result { browser.stopLoading() }
        continuation.resume(with: result)
    }
}
