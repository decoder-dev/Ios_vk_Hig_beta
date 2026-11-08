import SwiftUI

@MainActor
@Observable
final class DirectAuthViewModel {
    enum Challenge: Identifiable {
        case code(type: String, phoneMask: String?)
        case captcha(sid: String, imgUrl: String)
        var id: String {
            switch self {
            case .code: "code"
            case .captcha(let sid, _): "captcha-\(sid)"
            }
        }
    }

    var login = ""
    var password = ""
    var preset: VKClientPreset = .kate
    var isLoading = false
    var errorMessage: String?
    var challenge: Challenge?
    var codeInput = ""
    var captchaInput = ""

    private let service: VKDirectAuthService
    private let accounts: any AccountManagerProtocol
    private var captchaSid: String?
    private var onDone: () -> Void

    init(service: VKDirectAuthService = .init(), accounts: any AccountManagerProtocol = AccountManager.shared,
         onDone: @escaping () -> Void) {
        self.service = service
        self.accounts = accounts
        self.onDone = onDone
    }

    var canSubmit: Bool { !login.isEmpty && !password.isEmpty && !isLoading }

    func submit() async { await perform(.init()) }

    func submitCode() async {
        let code = codeInput.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        challenge = nil
        await perform(.init(code: code))
    }

    func submitCaptcha() async {
        let key = captchaInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, let sid = captchaSid else { return }
        challenge = nil
        await perform(.init(captchaSid: sid, captchaKey: key))
    }

    private func perform(_ answer: VKAuthChallengeAnswer) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let grant = try await service.login(username: login, password: password, preset: preset, answer: answer)
            try await accounts.addAccount(token: grant.accessToken, userId: grant.userId, secret: grant.secret,
                                          tokenType: .official, refreshToken: nil)
            password = ""
            onDone()
        } catch let e as VKAuthError {
            handle(e)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(_ e: VKAuthError) {
        switch e {
        case .needValidation(let type, let mask, _):
            codeInput = ""
            challenge = .code(type: type, phoneMask: mask)
        case .needCaptcha(let sid, let img):
            captchaSid = sid; captchaInput = ""
            challenge = .captcha(sid: sid, imgUrl: img)
        case .needVKIdCaptcha:
            errorMessage = "VK запросил проверку через VK ID. Войдите через веб-форму или по токену."
        default:
            errorMessage = e.errorDescription
        }
    }
}

struct DirectAuthView: View {
    @State private var model: DirectAuthViewModel

    init(onDone: @escaping () -> Void) {
        _model = State(initialValue: DirectAuthViewModel(onDone: onDone))
    }

    var body: some View {
        Form {
            Section("Клиент") {
                Picker("Клиент", selection: $model.preset) {
                    ForEach(VKClientPreset.all) { Text($0.title).tag($0) }
                }
            }
            Section("Учётная запись") {
                TextField("Телефон или e-mail", text: $model.login)
                    .textContentType(.username).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Пароль", text: $model.password).textContentType(.password)
            }
            if let error = model.errorMessage {
                Section { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            Section {
                Button { Task { await model.submit() } } label: {
                    HStack { Spacer(); if model.isLoading { ProgressView() } else { Text("Войти") }; Spacer() }
                }
                .disabled(!model.canSubmit)
            }
        }
        .navigationTitle("Вход по паролю")
        .sheet(item: $model.challenge) { challenge in
            switch challenge {
            case .code(let type, let mask):
                ValidateCodeView(type: type, phoneMask: mask, code: $model.codeInput) { Task { await model.submitCode() } }
            case .captcha(_, let url):
                CaptchaView(imageUrl: url, text: $model.captchaInput) { Task { await model.submitCaptcha() } }
            }
        }
    }
}

struct ValidateCodeView: View {
    let type: String
    let phoneMask: String?
    @Binding var code: String
    var onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Код", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode)
                } footer: {
                    Text(type.contains("sms") ? "Код отправлен по SMS\(phoneMask.map { " на \($0)" } ?? "")."
                                              : "Введите код из приложения-аутентификатора или Code Generator VK.")
                }
                Section { Button("Подтвердить", action: onSubmit).disabled(code.isEmpty) }
            }
            .navigationTitle("Подтверждение входа")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

struct CaptchaView: View {
    let imageUrl: String
    @Binding var text: String
    var onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit()
                        case .failure: Label("Не удалось загрузить капчу", systemImage: "exclamationmark.triangle")
                        default: ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .accessibilityLabel("Изображение капчи")
                    TextField("Текст с картинки", text: $text)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section { Button("Отправить", action: onSubmit).disabled(text.isEmpty) }
            }
            .navigationTitle("Капча")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
