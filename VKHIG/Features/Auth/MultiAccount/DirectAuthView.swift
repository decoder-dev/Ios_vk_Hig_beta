import SwiftUI

@MainActor
@Observable
final class DirectAuthViewModel {
    enum Challenge: Identifiable {
        case code(type: String, phoneMask: String?)
        case captcha(sid: String, imgUrl: String)
        /// VK security check page (`need_validation` without a code type).
        case web(URL)
        var id: String {
            switch self {
            case .code: "code"
            case .captcha(let sid, _): "captcha-\(sid)"
            case .web(let url): "web-\(url.absoluteString)"
            }
        }
    }

    var login = ""
    var password = ""
    var preset: VKClientPreset = .kate
    var isLoading = false
    var errorMessage: String?
    /// Shown when the in-app form cannot finish (VK ID captcha, unknown answer): VK's own web form handles it.
    var offersWebLogin = false
    var restoreURL: URL?
    var challenge: Challenge?
    var codeInput = ""
    var codeError: String?
    var captchaInput = ""
    var captchaError: String?
    var smsNotice: String?
    var smsResendAvailableAt: Date?

    private let service: VKDirectAuthService
    private let accounts: any AccountManagerProtocol
    private var captchaSid: String?
    private var validationSid: String?
    private var smsRequestedForSid: String?
    private var onDone: () -> Void

    init(service: VKDirectAuthService = .init(), accounts: any AccountManagerProtocol = AccountManager.shared,
         onDone: @escaping () -> Void) {
        self.service = service
        self.accounts = accounts
        self.onDone = onDone
    }

    var canSubmit: Bool {
        !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !isLoading
    }

    func submit() async {
        codeError = nil
        captchaError = nil
        await perform(.init())
    }

    func submitCode() async {
        let code = codeInput.filter { !$0.isWhitespace }
        guard !code.isEmpty, !isLoading else { return }
        codeError = nil
        await perform(.init(code: code))
    }

    /// App/push code is unavailable: ask VK to switch this login to SMS.
    func requestSms() async {
        guard !isLoading else { return }
        if let sid = validationSid { await sendSms(sid: sid, force: true) }
        await perform(.init(forceSms: true))
    }

    /// Same SMS session, new message (after the resend delay).
    func resendSms() async {
        guard let sid = validationSid else { return }
        await sendSms(sid: sid, force: true)
    }

    func submitCaptcha() async {
        let key = captchaInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, let sid = captchaSid, !isLoading else { return }
        captchaError = nil
        await perform(.init(captchaSid: sid, captchaKey: key))
    }

    func cancelChallenge() {
        challenge = nil
        codeInput = ""
        captchaInput = ""
    }

    /// The security-check page finished at `oauth.vk.com/blank.html`.
    func finishWebValidation(_ url: URL) async {
        challenge = nil
        let values = Self.fragmentValues(url)
        if let token = values["access_token"], !token.isEmpty {
            isLoading = true
            defer { isLoading = false }
            await save(token: token, userId: values["user_id"].flatMap { Int64($0) }, secret: values["secret"])
            return
        }
        if values["fail"] != nil || values["error"] != nil {
            errorMessage = values["error_description"] ?? "Проверка VK не пройдена. Попробуйте ещё раз или войдите через веб-форму VK."
            offersWebLogin = true
            return
        }
        // Check passed without a token in the redirect: the next password grant is accepted.
        await perform(.init())
    }

    static func fragmentValues(_ url: URL) -> [String: String] {
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

    private func sendSms(sid: String, force: Bool) async {
        if !force, smsRequestedForSid == sid { return }
        if let until = smsResendAvailableAt, until > Date() { return }
        smsRequestedForSid = sid
        let delay = await service.requestSms(validationSid: sid, preset: preset)
        smsResendAvailableAt = Date().addingTimeInterval(TimeInterval(delay ?? 60))
        smsNotice = "Запрос на SMS отправлен в VK"
    }

    private func perform(_ answer: VKAuthChallengeAnswer) async {
        isLoading = true
        errorMessage = nil
        offersWebLogin = false
        restoreURL = nil
        defer { isLoading = false }
        do {
            let grant = try await service.login(username: login, password: password, preset: preset, answer: answer)
            await save(token: grant.accessToken, userId: grant.userId, secret: grant.secret)
        } catch let e as VKAuthError {
            handle(e)
        } catch {
            challenge = nil
            errorMessage = error.localizedDescription
        }
    }

    private func save(token: String, userId: Int64?, secret: String?) async {
        do {
            try await accounts.addAccount(token: token, userId: userId, secret: secret,
                                          tokenType: .official, accountType: preset.accountType, refreshToken: nil)
            password = ""
            codeInput = ""
            challenge = nil
            onDone()
        } catch {
            challenge = nil
            let reason = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = "VK выдал токен, но аккаунт не сохранён: \(reason)"
        }
    }

    private func handle(_ e: VKAuthError) {
        switch e {
        case .needValidation(let type, let mask, let redirect, let sid):
            if type == "web" {
                if let redirect, let url = URL(string: redirect) {
                    challenge = .web(url)
                } else {
                    challenge = nil
                    errorMessage = "VK запросил дополнительную проверку. Войдите через веб-форму VK."
                    offersWebLogin = true
                }
                return
            }
            validationSid = sid
            codeError = nil
            challenge = .code(type: type, phoneMask: mask)
            if type.contains("sms"), let sid {
                Task { await sendSms(sid: sid, force: false) }
            }
        case .wrongCode:
            if case .code? = challenge {
                codeError = e.errorDescription
                codeInput = ""
            } else {
                errorMessage = e.errorDescription
            }
        case .needCaptcha(let sid, let img):
            if case .captcha? = challenge { captchaError = "Неверный текст. Введите символы с новой картинки." }
            captchaSid = sid
            captchaInput = ""
            challenge = .captcha(sid: sid, imgUrl: img)
        case .needVKIdCaptcha:
            challenge = nil
            errorMessage = "VK запросил проверку «Я не робот», которую проходят только в его веб-форме."
            offersWebLogin = true
        case .accountBlocked(_, let restore):
            challenge = nil
            errorMessage = e.errorDescription
            restoreURL = restore.flatMap(URL.init(string:))
        case .tooManyAttempts:
            if case .code? = challenge { codeError = e.errorDescription }
            else { challenge = nil; errorMessage = e.errorDescription }
        case .invalidCredentials:
            challenge = nil
            errorMessage = e.errorDescription
        case .networkError:
            if case .code? = challenge { codeError = e.errorDescription }
            else if case .captcha? = challenge { captchaError = e.errorDescription }
            else { errorMessage = e.errorDescription }
        default:
            challenge = nil
            errorMessage = e.errorDescription
            offersWebLogin = true
        }
    }
}

struct DirectAuthView: View {
    @State private var model: DirectAuthViewModel
    private let onDone: () -> Void

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
        _model = State(initialValue: DirectAuthViewModel(onDone: onDone))
    }

    var body: some View {
        Form {
            Section {
                Picker("Клиент", selection: $model.preset) {
                    ForEach(VKClientPreset.all) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Клиент")
            } footer: {
                Text("Временный вход для тестов. Токен выдаётся выбранному клиенту VK.")
            }
            Section("Учётная запись") {
                TextField("Телефон или e-mail", text: $model.login)
                    .textContentType(.username).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.next)
                SecureField("Пароль", text: $model.password)
                    .textContentType(.password)
                    .submitLabel(.go)
                    .onSubmit { if model.canSubmit { Task { await model.submit() } } }
            }
            if let error = model.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.footnote)
                    if let restore = model.restoreURL {
                        Link("Восстановить доступ в VK", destination: restore)
                    }
                    if model.offersWebLogin {
                        NavigationLink("Войти через веб-форму VK") { WebLoginScreen(onDone: onDone) }
                    }
                }
            }
            Section {
                Button { Task { await model.submit() } } label: {
                    HStack { Spacer(); if model.isLoading && model.challenge == nil { ProgressView() } else { Text("Войти") }; Spacer() }
                }
                .disabled(!model.canSubmit)
            } footer: {
                Text("Если VK попросит подтверждение, код придёт в SMS или в приложении VK. Пароль не сохраняется.")
            }
        }
        .navigationTitle("Вход по паролю")
        .sheet(item: $model.challenge, onDismiss: { if !model.isLoading { model.cancelChallenge() } }) { challenge in
            switch challenge {
            case .code(let type, let mask):
                ValidateCodeView(model: model, type: type, phoneMask: mask)
            case .captcha(_, let url):
                CaptchaView(imageUrl: url, text: $model.captchaInput, error: model.captchaError, isLoading: model.isLoading,
                            onCancel: { model.cancelChallenge() }) { Task { await model.submitCaptcha() } }
            case .web(let url):
                NavigationStack {
                    VKRedirectWebView(url: url) { result in Task { await model.finishWebValidation(result) } }
                        .ignoresSafeArea(edges: .bottom)
                        .navigationTitle("Проверка VK")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { model.cancelChallenge() } } }
                }
            }
        }
    }
}

struct ValidateCodeView: View {
    @Bindable var model: DirectAuthViewModel
    let type: String
    let phoneMask: String?

    private var hint: String {
        if type.contains("sms") { return "Код придёт по SMS\(phoneMask.map { " на \($0)" } ?? ""). Иногда это занимает до минуты." }
        if type == "2fa_callreset" { return "Вам позвонят. Введите последние цифры номера, с которого поступил звонок." }
        if type.contains("email") { return "Код отправлен на почту, привязанную к аккаунту." }
        return "Введите код из приложения VK (уведомление или «Генератор кодов») либо из приложения-аутентификатора."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Код", text: $model.codeInput)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.title3.monospacedDigit())
                        .onSubmit { Task { await model.submitCode() } }
                } footer: {
                    Text(hint)
                }
                if let error = model.codeError {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
                Section {
                    Button { Task { await model.submitCode() } } label: {
                        HStack { Spacer(); if model.isLoading { ProgressView() } else { Text("Подтвердить") }; Spacer() }
                    }
                    .disabled(model.codeInput.filter { !$0.isWhitespace }.isEmpty || model.isLoading)
                }
                Section {
                    if type.contains("sms") {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let remaining = Int((model.smsResendAvailableAt ?? .distantPast).timeIntervalSince(context.date).rounded(.up))
                            Button(remaining > 0 ? "Отправить ещё раз через \(remaining) с" : "Отправить SMS ещё раз") {
                                Task { await model.resendSms() }
                            }
                            .disabled(remaining > 0 || model.isLoading)
                        }
                    } else {
                        Button("Получить код по SMS") { Task { await model.requestSms() } }
                            .disabled(model.isLoading)
                    }
                    if let notice = model.smsNotice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Подтверждение входа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { model.cancelChallenge() } } }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(model.isLoading)
    }
}

struct CaptchaView: View {
    let imageUrl: String
    @Binding var text: String
    var error: String? = nil
    var isLoading = false
    var onCancel: (() -> Void)? = nil
    var onSubmit: () -> Void
    @State private var reload = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        case .failure:
                            Button("Не удалось загрузить капчу. Повторить") { reload += 1 }
                        default: ProgressView()
                        }
                    }
                    .id(reload)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityLabel("Изображение капчи")
                    TextField("Текст с картинки", text: $text)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onSubmit(onSubmit)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red).font(.footnote) }
                }
                Section {
                    Button(action: onSubmit) {
                        HStack { Spacer(); if isLoading { ProgressView() } else { Text("Отправить") }; Spacer() }
                    }
                    .disabled(text.isEmpty || isLoading)
                }
            }
            .navigationTitle("Капча")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: onCancel) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isLoading)
    }
}
