import SwiftUI

/// S01/S02 — official VK ID entry. No password fields.
struct AuthStubView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var authError: String?
    @State private var isAuthorizing = false
    @State private var showOtherMethods = false

    var body: some View {
        NavigationStack {
            VStack(spacing: VKStyle.Spacing.lg) {
                Spacer(minLength: VKStyle.Spacing.xl)

                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(VKStyle.accent)
                    .accessibilityHidden(true)

                Text("VK HIG")
                    .font(.largeTitle.bold())

                Text("Войдите через VK ID, чтобы открыть свой профиль и доступные разделы ВКонтакте.")
                    .font(.body)
                    .foregroundStyle(VKStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VKStyle.Spacing.xl)


                Button {
                    Task { await attemptVKID() }
                } label: {
                    Group {
                        if isAuthorizing {
                            ProgressView()
                        } else {
                            Text("Войти через VK ID")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: VKStyle.Size.tapTargetMin)
                }
                .buttonStyle(.borderedProminent)
                .tint(VKStyle.accent)
                .disabled(isAuthorizing)
                .padding(.horizontal, VKStyle.Spacing.md)
                .accessibilityHint("Открывает официальный вход VK ID")

                Button {
                    env.enterShellWithoutAuth()
                } label: {
                    Text("Посмотреть демоверсию")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: VKStyle.Size.tapTargetMin)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, VKStyle.Spacing.md)
                .accessibilityHint("Открывает приложение с демоданными без подключения к VK")

                Button("Другие способы входа") { showOtherMethods = true }
                    .frame(minHeight: VKStyle.Size.tapTargetMin)

                if let authError {
                    Text(authError)
                        .font(.footnote)
                        .foregroundStyle(VKStyle.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VKStyle.Spacing.md)
                }

                NavigationLink(value: AppRoute.onboarding) {
                    Text("О приложении")
                        .frame(minHeight: VKStyle.Size.tapTargetMin)
                }

                Text("Набор функций зависит от разрешений вашего аккаунта и приложения.")
                    .font(.caption)
                    .foregroundStyle(VKStyle.secondaryText)

                Spacer()
            }
            .background(VKStyle.groupedCanvas)
            .navigationTitle("Вход")
            .navigationBarTitleDisplayMode(.inline)
            .withAppRoutes()
        }
        .sheet(isPresented: $showOtherMethods) {
            AddAccountHubView { showOtherMethods = false }
        }
    }

    private func attemptVKID() async {
        isAuthorizing = true
        defer { isAuthorizing = false }
        let result = await env.signInWithVKID()
        switch result {
        case .success:
            authError = nil
        case .failure(let error):
            authError = error.localizedDescription
        }
    }
}

#Preview {
    AuthStubView()
        .environment(AppEnvironment())
}
