import SwiftUI
import Observation

/// Shows VK API challenges (error 14 captcha, error 17 validation) over the app and hands the answer back to
/// the waiting request so it can be retried once. The user solves the challenge; nothing is solved for them.
@MainActor
@Observable
final class VKChallengeCenter: VKChallengeResolving {
    static let shared = VKChallengeCenter()

    enum Prompt: Identifiable {
        case captcha(sid: String, imageURL: String)
        case validation(URL)
        var id: String {
            switch self {
            case .captcha(let sid, _): "captcha-\(sid)"
            case .validation(let url): "validation-\(url.absoluteString)"
            }
        }
    }

    var prompt: Prompt?
    var captchaText = ""

    @ObservationIgnored private var captchaContinuation: CheckedContinuation<(sid: String, key: String)?, Never>?
    @ObservationIgnored private var validationContinuation: CheckedContinuation<Bool, Never>?
    /// A prompt the user never sees (another sheet on top) must not hang the request forever.
    private let timeout: Duration = .seconds(180)

    func resolveCaptcha(sid: String, imgUrl: String) async -> (sid: String, key: String)? {
        guard prompt == nil, captchaContinuation == nil, validationContinuation == nil else { return nil }
        captchaText = ""
        let promptID = "captcha-\(sid)"
        scheduleTimeout(for: promptID)
        return await withCheckedContinuation { continuation in
            captchaContinuation = continuation
            prompt = .captcha(sid: sid, imageURL: imgUrl)
        }
    }

    func resolveValidation(redirectUri: String) async -> Bool {
        guard prompt == nil, captchaContinuation == nil, validationContinuation == nil,
              let url = URL(string: redirectUri), url.scheme == "https" else { return false }
        scheduleTimeout(for: "validation-\(url.absoluteString)")
        return await withCheckedContinuation { continuation in
            validationContinuation = continuation
            prompt = .validation(url)
        }
    }

    func submitCaptcha() {
        let key = captchaText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard case .captcha(let sid, _)? = prompt, !key.isEmpty, let continuation = captchaContinuation else { return }
        captchaContinuation = nil
        prompt = nil
        continuation.resume(returning: (sid: sid, key: key))
    }

    func finishValidation(_ url: URL) {
        let values = VKOAuthRedirect.values(url)
        let passed = values["fail"] == nil && values["error"] == nil
        prompt = nil
        validationContinuation?.resume(returning: passed)
        validationContinuation = nil
    }

    /// Cancel button, swipe-down or timeout: the original request fails with its VK error.
    func cancel() {
        prompt = nil
        captchaContinuation?.resume(returning: nil)
        captchaContinuation = nil
        validationContinuation?.resume(returning: false)
        validationContinuation = nil
    }

    private func scheduleTimeout(for promptID: String) {
        let limit = timeout
        Task { [weak self] in
            try? await Task.sleep(for: limit)
            guard let self, self.prompt?.id == promptID else { return }
            self.cancel()
        }
    }
}

/// Root-level presenter for `VKChallengeCenter`.
struct VKChallengeSheetModifier: ViewModifier {
    @Bindable var center: VKChallengeCenter

    func body(content: Content) -> some View {
        content.sheet(item: $center.prompt, onDismiss: { center.cancel() }) { prompt in
            switch prompt {
            case .captcha(_, let imageURL):
                CaptchaView(imageUrl: imageURL, text: $center.captchaText,
                            onCancel: { center.cancel() }) { center.submitCaptcha() }
            case .validation(let url):
                NavigationStack {
                    VKRedirectWebView(url: url) { result in center.finishValidation(result) }
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("Проверка VK")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { center.cancel() } } }
                }
            }
        }
    }
}
