import SwiftUI

/// S01/S02 — official VK ID entry. No password fields.
struct AuthStubView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var authError: String?
    @State private var isAuthorizing = false

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

                Text("Sign-in uses official VK ID (OAuth 2.1 + PKCE). No password fields and no third-party client keys.")
                    .font(.body)
                    .foregroundStyle(VKStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VKStyle.Spacing.xl)

                VStack(alignment: .leading, spacing: VKStyle.Spacing.sm) {
                    Label(
                        AppSecrets.hasVKIDCredentials
                            ? "Client id loaded from local/CI config"
                            : "Add VK_ID_CLIENT_ID (GitHub secret or Secrets.xcconfig)",
                        systemImage: "1.circle"
                    )
                    Label("Register redirect URI \(AppSecrets.vkRedirectURI)", systemImage: "2.circle")
                    Label("Link VKID iOS SDK (PKCE); Keychain tokens only", systemImage: "3.circle")
                    Text("Client secret stays out of the app binary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(VKStyle.Spacing.md)
                .background(VKStyle.cell, in: RoundedRectangle(cornerRadius: VKStyle.Radius.medium))
                .padding(.horizontal, VKStyle.Spacing.md)

                Button {
                    Task { await attemptVKID() }
                } label: {
                    Group {
                        if isAuthorizing {
                            ProgressView()
                        } else {
                            Text("Continue with VK ID")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: VKStyle.Size.tapTargetMin)
                }
                .buttonStyle(.borderedProminent)
                .tint(VKStyle.accent)
                .disabled(isAuthorizing)
                .padding(.horizontal, VKStyle.Spacing.md)
                .accessibilityHint("Starts official VK ID when credentials and SDK are configured")

                Button {
                    env.enterShellWithoutAuth()
                } label: {
                    Text("Continue with fixture UI shell")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: VKStyle.Size.tapTargetMin)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, VKStyle.Spacing.md)
                .accessibilityHint("Opens tabs with fixture repositories; does not contact VK")

                if let authError {
                    Text(authError)
                        .font(.footnote)
                        .foregroundStyle(VKStyle.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VKStyle.Spacing.md)
                }

                NavigationLink(value: AppRoute.onboarding) {
                    Text("What is VK HIG? (onboarding)")
                        .frame(minHeight: VKStyle.Size.tapTargetMin)
                }

                Text("Live VK API success is never simulated.")
                    .font(.caption)
                    .foregroundStyle(VKStyle.secondaryText)

                Spacer()
            }
            .background(VKStyle.groupedCanvas)
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .withAppRoutes()
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
                + " — supply VK ID client id/redirect (see output/BLOCKERS.md)."
        }
    }
}

#Preview {
    AuthStubView()
        .environment(AppEnvironment())
}
