import SwiftUI

/// Shared "validate with users.get, then save" path for pasted / scanned tokens.
@MainActor
enum TokenImporter {
    static func importToken(_ raw: String, accounts: any AccountManagerProtocol = AccountManager.shared) async throws {
        guard let parsed = VKTokenParser.parse(raw) else { throw VKAuthError.parsingError }
        // addAccount runs users.get with this token and rejects it (error 5 -> tokenRevoked) before saving.
        try await accounts.addAccount(token: parsed.token, userId: parsed.userId, secret: nil,
                                      tokenType: .custom, accountType: nil, refreshToken: nil)
    }
}

struct TokenEntryView: View {
    var onDone: () -> Void
    @State private var text = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                TextField("vk1.a.… или 85 hex-символов", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(.footnote, design: .monospaced))
                Button("Вставить из буфера") { text = UIPasteboard.general.string ?? text }
            } footer: { Text("Токен проверяется запросом users.get перед сохранением.") }
            if let error { Section { Text(error).foregroundStyle(.red).font(.footnote) } }
            Section {
                Button {
                    Task {
                        isLoading = true; error = nil
                        defer { isLoading = false }
                        do { try await TokenImporter.importToken(text); text = ""; onDone() }
                        catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
                    }
                } label: { HStack { Spacer(); if isLoading { ProgressView() } else { Text("Войти по токену") }; Spacer() } }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
        }
        .navigationTitle("Токен")
    }
}

struct QRTokenLoginView: View {
    var onDone: () -> Void
    @State private var error: String?
    @State private var isLoading = false
    @State private var resume = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            QRScannerView(onCode: handle, onFailure: { error = $0 }, resumeToken: resume)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                if isLoading { ProgressView().tint(.white) }
                Text(error ?? "Наведите камеру на QR-код с токеном")
                    .font(.footnote).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding().frame(maxWidth: .infinity).background(.black.opacity(0.6))
        }
        .navigationTitle("QR-код")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handle(_ code: String) {
        Task {
            isLoading = true; error = nil
            defer { isLoading = false }
            do { try await TokenImporter.importToken(code); onDone() }
            catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                resume += 1 // keep scanning
            }
        }
    }
}

struct WebLoginScreen: View {
    var onDone: () -> Void
    @State private var error: String?

    var body: some View {
        VKWebAuthView { result in
            Task { @MainActor in
                switch result {
                case .success(let r):
                    do {
                        try await AccountManager.shared.addAccount(
                            token: r.accessToken, userId: r.userId, secret: nil, tokenType: .web,
                            accountType: .kateMobile, refreshToken: nil)
                        onDone()
                    } catch { self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
                case .failure(let e): error = e.errorDescription
                }
            }
        }
        .ignoresSafeArea()
        .navigationTitle("Вход через VK")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ошибка входа", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }
}

/// Entry point that lists all sign-in scenarios.
struct AddAccountHubView: View {
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Логин и пароль") { DirectAuthView(onDone: onDone) }
                NavigationLink("Веб-форма VK (OAuth)") { WebLoginScreen(onDone: onDone) }
                NavigationLink("Вставить токен") { TokenEntryView(onDone: onDone) }
                NavigationLink("Сканировать QR") { QRTokenLoginView(onDone: onDone) }
                NavigationLink("Подтвердить вход на другом устройстве") { QRConfirmLoginView() }
            }
            .navigationTitle("Добавить аккаунт")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Account list with quick switching.
struct AccountSwitcherView: View {
    @State private var accounts: [VKAccount] = AccountManager.shared.accounts.value
    @State private var showAdd = false

    var body: some View {
        List {
            ForEach(accounts) { a in
                Button { AccountManager.shared.switchAccount(to: a.userId) } label: {
                    HStack {
                        AsyncImage(url: a.avatarUrl.flatMap(URL.init)) { $0.resizable() } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 40, height: 40).clipShape(Circle())
                        Text(a.displayName)
                        Spacer()
                        if a.isActive { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                .foregroundStyle(.primary)
                .swipeActions { Button("Удалить", role: .destructive) { AccountManager.shared.removeAccount(userId: a.userId) } }
            }
            Button("Добавить аккаунт") { showAdd = true }
        }
        .navigationTitle("Аккаунты")
        .onReceive(AccountManager.shared.accounts) { accounts = $0 }
        .sheet(isPresented: $showAdd) { AddAccountHubView { showAdd = false } }
    }
}
