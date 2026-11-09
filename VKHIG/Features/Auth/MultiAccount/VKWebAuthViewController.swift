import SwiftUI
import UIKit
import WebKit

struct VKWebAuthResult: Sendable {
    let accessToken: String
    let userId: Int64
    let expiresIn: Int?
}

/// Recognises VK's OAuth landing page on either domain (`oauth.vk.com` / `oauth.vk.ru`), with the result
/// in the fragment or the query. VK may move between the two domains during the flow.
enum VKOAuthRedirect {
    static func isBlankPage(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased() else { return false }
        return ["oauth.vk.com", "oauth.vk.ru"].contains(host) && url.path == "/blank.html"
    }

    static func values(_ url: URL) -> [String: String] {
        var values: [String: String] = [:]
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        for item in components?.queryItems ?? [] { values[item.name] = item.value }
        if let fragment = components?.fragment {
            var parsed = URLComponents()
            parsed.query = fragment
            for item in parsed.queryItems ?? [] { values[item.name] = item.value }
        }
        return values
    }

    /// Cancellations and "frame load interrupted" are normal while VK redirects; they are not failures.
    static func isBenign(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        if ns.domain == "WebKitErrorDomain" && (ns.code == 102 || ns.code == 204) { return true }
        return false
    }
}

/// OAuth 2.0 implicit flow in WKWebView.
final class VKWebAuthViewController: UIViewController, WKNavigationDelegate {
    private let clientId: String
    private let scope: VKScopes
    private let onFinish: (Result<VKWebAuthResult, VKAuthError>) -> Void
    private var finished = false
    private let spinner = UIActivityIndicatorView(style: .medium)
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
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
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
        guard let url = navigationAction.request.url, VKOAuthRedirect.isBlankPage(url) else {
            decisionHandler(.allow); return
        }
        let values = VKOAuthRedirect.values(url)
        // Some redirects arrive here without the fragment; let the page commit and read webView.url instead.
        guard values["access_token"] != nil || values["error"] != nil else { decisionHandler(.allow); return }
        decisionHandler(.cancel)
        complete(with: url)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        if let url = webView.url, VKOAuthRedirect.isBlankPage(url) {
            webView.stopLoading()
            complete(with: url)
        }
    }

    /// Safety net: if the landing page still got rendered (server redirect, domain switch), read its URL.
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url, VKOAuthRedirect.isBlankPage(url) { complete(with: url) }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
        if let url = webView.url, VKOAuthRedirect.isBlankPage(url) { complete(with: url) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
        guard !VKOAuthRedirect.isBenign(error) else { return }
        fail(.networkError(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
        guard !VKOAuthRedirect.isBenign(error) else { return }
        fail(.networkError(error))
    }

    private func complete(with url: URL) {
        let p = VKOAuthRedirect.values(url)
        guard let token = p["access_token"], !token.isEmpty, let uid = p["user_id"].flatMap({ Int64($0) }) else {
            if let description = p["error_description"], !description.isEmpty {
                fail(.server("VK: \(description)"))
            } else {
                fail(p["error"] != nil ? .invalidCredentials : .parsingError)
            }
            return
        }
        guard !finished else { return }
        finished = true
        onFinish(.success(VKWebAuthResult(accessToken: token, userId: uid, expiresIn: p["expires_in"].flatMap { Int($0) })))
    }

    /// Failures are reported but never latch: a later redirect with a token still completes the login.
    private func fail(_ e: VKAuthError) {
        guard !finished else { return }
        onFinish(.failure(e))
    }
}

struct VKWebAuthView: UIViewControllerRepresentable {
    var onFinish: (Result<VKWebAuthResult, VKAuthError>) -> Void
    func makeUIViewController(context: Context) -> VKWebAuthViewController {
        VKWebAuthViewController(onFinish: onFinish)
    }
    func updateUIViewController(_ vc: VKWebAuthViewController, context: Context) {}
}

/// Any VK page that ends at `oauth.vk.com/blank.html` (security check after a password grant).
struct VKRedirectWebView: UIViewRepresentable {
    let url: URL
    var onRedirect: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onRedirect: onRedirect) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onRedirect: (URL) -> Void
        private var done = false
        init(onRedirect: @escaping (URL) -> Void) { self.onRedirect = onRedirect }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, VKOAuthRedirect.isBlankPage(url) {
                decisionHandler(.cancel)
                finish(url)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if let url = webView.url, VKOAuthRedirect.isBlankPage(url) { finish(url) }
        }

        private func finish(_ url: URL) {
            guard !done else { return }
            done = true
            onRedirect(url)
        }
    }
}
