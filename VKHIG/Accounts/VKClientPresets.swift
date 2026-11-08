import Foundation

/// Known OAuth client identities for the password grant.
/// Kept in one file on purpose (documented exception to the "no hardcoded secrets" rule in AGENTS.md).
struct VKClientPreset: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let clientId: String
    let clientSecret: String
    let userAgent: String

    static let kate = VKClientPreset(
        id: "kate", title: "Kate Mobile", clientId: "2685278",
        clientSecret: "lxhD8OD7dMsqO7PRjSos", userAgent: "KateMobile/56 lite")
    static let officialAndroid = VKClientPreset(
        id: "android", title: "Официальный Android", clientId: "2274003",
        clientSecret: "hHbZxrka2uZ6jB1inYsH", userAgent: "VK/6.35")
    static let officialIPhone = VKClientPreset(
        id: "iphone", title: "Официальный iPhone", clientId: "3140623",
        clientSecret: "VeWdmVclDCtn6ihuP1nt", userAgent: "VK/6.35")

    static let vkMe = VKClientPreset(
        id: "vkme", title: "VK Me", clientId: "6146827",
        clientSecret: "qVxWRF1CwHERuIrKBnqe", userAgent: "VK/6.35")
    static let vkAdmin = VKClientPreset(
        id: "vkadmin", title: "VK Admin", clientId: "5776857",
        clientSecret: "wpeEslv1VnJgE0mkeL04", userAgent: "VK/6.35")

    static let all: [VKClientPreset] = [.kate, .officialAndroid, .officialIPhone, .vkMe, .vkAdmin]
}
