import Foundation

/// Login-screen-facing OAuth client identity for the password grant. Built from `VKAccountType`
/// (the single source of truth for id/secret/User-Agent) so the two never drift apart.
struct VKClientPreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let clientId: String
    let clientSecret: String
    let userAgent: String
    let accountType: VKAccountType

    init(_ accountType: VKAccountType) {
        self.accountType = accountType
        self.id = "type-\(accountType.rawValue)"
        self.title = accountType.title
        self.clientId = accountType.clientId
        self.clientSecret = accountType.clientSecret
        self.userAgent = accountType.userAgent
    }

    static let kate = VKClientPreset(.kateMobile)
    static let officialAndroid = VKClientPreset(.vkAndroid)
    static let officialIPhone = VKClientPreset(.vkIos)
    static let vkMe = VKClientPreset(.vkMe)
    static let vkAdmin = VKClientPreset(.vkAdmin)

    static let all: [VKClientPreset] = VKAccountType.allCases.map(VKClientPreset.init)
}
