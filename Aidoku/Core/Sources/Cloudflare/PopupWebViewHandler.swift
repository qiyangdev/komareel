//
//  PopupWebViewHandler.swift
//  Aidoku
//
//  Created by Skitty on 6/16/25.
//

import WebKit

@MainActor
protocol PopupWebViewHandler {
    func received(response: WKNavigationResponse)
    func navigated(webView: WKWebView, for request: URLRequest)
    func canceled(request: URLRequest)
}
