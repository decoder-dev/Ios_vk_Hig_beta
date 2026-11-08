import Foundation

extension VKScopes {
    /// Names used by `CapabilityRegistry` (same spelling as VK scope strings).
    var names: Set<String> {
        let map: [(VKScopes, String)] = [
            (.notify, "notify"), (.friends, "friends"), (.photos, "photos"), (.audio, "audio"),
            (.video, "video"), (.stories, "stories"), (.pages, "pages"), (.status, "status"),
            (.notes, "notes"), (.messages, "messages"), (.wall, "wall"), (.ads, "ads"),
            (.offline, "offline"), (.docs, "docs"), (.groups, "groups"),
            (.notifications, "notifications"), (.stats, "stats"), (.email, "email"), (.market, "market")
        ]
        return Set(map.filter { contains($0.0) }.map(\.1))
    }
}

extension VKAPISession {
    /// Real granted permissions of the active token (`account.getAppPermissions` bitmask).
    func fetchGrantedScopes(userId: Int64, credentials: VKCredentials? = nil) async throws -> VKScopes {
        struct Envelope: Decodable { let response: Int? }
        let data = try await call(method: "account.getAppPermissions",
                                  params: ["user_id": String(userId)], credentials: credentials)
        guard let mask = (try? JSONDecoder().decode(Envelope.self, from: data))?.response else {
            throw VKAuthError.parsingError
        }
        return VKScopes(rawValue: mask)
    }
}

/// One place that answers "who is signed in and with which token".
/// A multi-account session (`AccountManager`) takes precedence; otherwise the VK ID session is used.
@MainActor
enum VKSession {
    private(set) static var accountGrants: Set<String> = []

    static var activeAccount: VKAccount? { AccountManager.shared.activeAccount.value }

    static var currentUserID: Int64? { activeAccount?.userId ?? VKIDAuthCoordinator.shared.userID }

    static var hasLiveSession: Bool {
        activeAccount != nil || VKIDAuthCoordinator.shared.restoreSessionIfPossible()
    }

    static var grants: Set<String> {
        activeAccount != nil ? accountGrants : VKIDAuthCoordinator.shared.grants
    }

    static func accessToken() async -> String? {
        if let account = activeAccount { return account.token }
        return await VKIDAuthCoordinator.shared.freshAccessToken()
    }

    /// Loads real scopes for the active account. Unknown (request failed) = empty = features stay gated.
    static func refreshAccountGrants() async {
        guard let account = activeAccount else { accountGrants = []; return }
        let creds = VKCredentials(token: account.token, tokenType: account.tokenType,
                                  secret: account.secret, accountType: account.accountType)
        let scopes = try? await VKAPISession.shared.fetchGrantedScopes(userId: account.userId, credentials: creds)
        guard activeAccount?.userId == account.userId else { return } // switched meanwhile
        accountGrants = (scopes?.names ?? []).union(scopes == nil ? [] : ["vkid.personal_info"])
    }

    static func fetchIdentity() async throws -> UserProfile {
        if let a = activeAccount {
            let name = a.displayName
            return UserProfile(id: a.userId, displayName: name, initials: VKCatalogService.initials(name),
                               city: nil, statusText: nil)
        }
        return try await VKIDAuthCoordinator.shared.fetchIdentity()
    }
}
