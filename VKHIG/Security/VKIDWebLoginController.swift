import UIKit
import WebKit

/// Official VK ID login page for an https redirect URI that the app does not own as a domain.
/// ASWebAuthenticationSession can only return to custom schemes or associated domains, so the
/// final navigation to the registered redirect is intercepted here and never leaves the app.
@MainActor
final class VKIDWebLoginController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let startURL: URL
    private let redirect: URL
    private var completion: ((Result<URL, VKIDAuthError>) -> Void)?
    private let webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        return WKWebView(frame: .zero, configuration: configuration)
    }()
    private let progress = UIProgressView(progressViewStyle: .bar)
    private var observation: NSKeyValueObservation?

    init(url: URL, redirect: URL, completion: @escaping (Result<URL, VKIDAuthError>) -> Void) {
        startURL = url
        self.redirect = redirect
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Вход VK ID"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in self?.finish(.failure(.cancelled)) })
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        progress.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        view.addSubview(progress)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            progress.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progress.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        observation = webView.observe(\.estimatedProgress) { [weak self] web, _ in
            let value = Float(web.estimatedProgress)
            Task { @MainActor in self?.progress.setProgress(value, animated: true); self?.progress.isHidden = value >= 1 }
        }
        webView.load(URLRequest(url: startURL))
    }

    /// Dismissal by swipe counts as cancellation.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if completion != nil, navigationController?.isBeingDismissed ?? isBeingDismissed { finish(.failure(.cancelled), dismiss: false) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }
        if Self.matches(url, redirect: redirect) {
            finish(.success(url))
            return .cancel
        }
        // VK ID pages are https only; anything else (app links, other schemes) stays out of the login sheet.
        return url.scheme == "https" || url.scheme == "about" ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }

    /// Popups opened by the VK page load in the same view.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    static func matches(_ url: URL, redirect: URL) -> Bool {
        guard url.scheme?.lowercased() == redirect.scheme?.lowercased(), url.host?.lowercased() == redirect.host?.lowercased(), url.port == redirect.port else { return false }
        return normalizedPath(url.path) == normalizedPath(redirect.path)
    }
    static func normalizedPath(_ path: String) -> String { path == "/" ? "" : path }

    private func report(_ error: Error) {
        let error = error as NSError
        // Cancelled loads are our own redirect interception or a superseded navigation.
        guard completion != nil, !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled),
              !(error.domain == "WebKitErrorDomain" && error.code == 102) else { return }
        let alert = UIAlertController(title: "Страница VK ID не загрузилась", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Повторить", style: .default) { [weak self] _ in
            guard let self else { return }
            self.webView.load(URLRequest(url: self.webView.url ?? self.startURL))
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { [weak self] _ in self?.finish(.failure(.cancelled)) })
        present(alert, animated: true)
    }

    private func finish(_ result: Result<URL, VKIDAuthError>, dismiss: Bool = true) {
        guard let completion else { return }
        self.completion = nil
        webView.stopLoading()
        if dismiss { (navigationController ?? self).dismiss(animated: true) }
        completion(result)
    }
}
