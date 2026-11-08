import SwiftUI
import UIKit
import WebKit

struct VKWebAuthResult: Sendable {
    let accessToken: String
    let userId: Int64
    let expiresIn: Int?
}

/// OAuth 2.0 implicit flow in WKWebView.
final class VKWebAuthViewController: UIViewController, WKNavigationDelegate {
    static let blankPrefix = "https://oauth.vk.com/blank.html#"

    private let clientId: String
    private let scope: VKScopes
    private let onFinish: (Result<VKWebAuthResult, VKAuthError>) -> Void
    private var finished = false
    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        // Isolated, non-persistent store: signing in a second account never reuses the first one's cookies.
        config.websiteDataStore = .nonPersistent()
        let v = WKWebView(frame: .zero, configuration: config)
        v.navigationDelegate = self
        return v
    }()

    init(clientId: String = VKClientPreset.kate.clientId, scope: VKScopes = .fullAccess,
         onFinish: @escaping (Result<VKWebAuthResult, VKAuthError>) -> Void) {
        self.clientId = clientId
        self.scope = scope
        self.onFinish = onFinish
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    override func loadView() { view = webView }

    override func viewDidLoad() {
        super.viewDidLoad()
        var c = URLComponents(string: "https://oauth.vk.com/authorize")
        c?.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "redirect_uri", value: "https://oauth.vk.com/blank.html"),
            .init(name: "display", value: "mobile"),
            .init(name: "scope", value: String(scope.rawValue)),
            .init(name: "response_type", value: "token"),
            .init(name: "v", value: VKRequestAdapter.apiVersion),
            .init(name: "revoke", value: "1")
        ]
        if let url = c?.url { webView.load(URLRequest(url: url)) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              url.absoluteString.hasPrefix(Self.blankPrefix) else {
            decisionHandler(.allow); return
        }
        decisionHandler(.cancel)
        complete(with: url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(.networkError(error))
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(.networkError(error))
    }

    private func complete(with url: URL) {
        var f = URLComponents()
        f.query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment
        var p: [String: String] = [:]
        for i in f.queryItems ?? [] { p[i.name] = i.value }
        guard let token = p["access_token"], !token.isEmpty, let uid = p["user_id"].flatMap({ Int64($0) }) else {
            fail(p["error"] != nil ? .invalidCredentials : .parsingError); return
        }
        finish(.success(VKWebAuthResult(accessToken: token, userId: uid, expiresIn: p["expires_in"].flatMap { Int($0) })))
    }

    private func fail(_ e: VKAuthError) { finish(.failure(e)) }

    private func finish(_ r: Result<VKWebAuthResult, VKAuthError>) {
        guard !finished else { return }
        finished = true
        onFinish(r)
    }
}

struct VKWebAuthView: UIViewControllerRepresentable {
    var onFinish: (Result<VKWebAuthResult, VKAuthError>) -> Void
    func makeUIViewController(context: Context) -> VKWebAuthViewController {
        VKWebAuthViewController(onFinish: onFinish)
    }
    func updateUIViewController(_ vc: VKWebAuthViewController, context: Context) {}
}
